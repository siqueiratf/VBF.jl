// Storage-only streaming migration. No APN mathematics or classification logic.
// Build: c++ -O3 -std=c++17 compact_closure_ledger.cpp -lsqlite3 -lzstd -lcrypto -o compact_closure_ledger
#include <sqlite3.h>
#include <zstd.h>
#include <openssl/sha.h>
#include <sys/statvfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

using Bytes=std::vector<unsigned char>;
void require(bool ok,const std::string& message){if(!ok)throw std::runtime_error(message);}
void sql(sqlite3* db,const std::string& text){char* e=nullptr;int rc=sqlite3_exec(db,text.c_str(),nullptr,nullptr,&e);std::string why=e?e:"";sqlite3_free(e);require(rc==SQLITE_OK,text+": "+why);}
struct Query{
    sqlite3_stmt* s=nullptr;
    Query(sqlite3* db,const std::string& text){require(sqlite3_prepare_v2(db,text.c_str(),-1,&s,nullptr)==SQLITE_OK,sqlite3_errmsg(db));}
    ~Query(){sqlite3_finalize(s);}
    bool step(){int rc=sqlite3_step(s);require(rc==SQLITE_ROW||rc==SQLITE_DONE,sqlite3_errmsg(sqlite3_db_handle(s)));return rc==SQLITE_ROW;}
};
std::string text(sqlite3_stmt* s,int i){const auto* p=sqlite3_column_text(s,i);return p?std::string(reinterpret_cast<const char*>(p),sqlite3_column_bytes(s,i)):"";}
std::string quote(std::string s){std::string r="\"";for(char c:s){r+=c;if(c=='\"')r+=c;}return r+'\"';}
void u32(Bytes& b,uint32_t v){for(int i=0;i<4;++i)b.push_back((v>>(8*i))&255);}
void u64(Bytes& b,uint64_t v){for(int i=0;i<8;++i)b.push_back((v>>(8*i))&255);}
std::string hex(const unsigned char* p,size_t n){std::ostringstream s;for(size_t i=0;i<n;++i)s<<std::hex<<std::setw(2)<<std::setfill('0')<<int(p[i]);return s.str();}
std::array<unsigned char,32> hash(const Bytes& b){std::array<unsigned char,32> h;SHA256(b.data(),b.size(),h.data());return h;}
Bytes pack(const Bytes& raw){
    Bytes b={'V','B','F','C','H','N','0','1'};u64(b,raw.size());auto h=hash(raw);b.insert(b.end(),h.begin(),h.end());
    auto n=b.size();b.resize(n+ZSTD_compressBound(raw.size()));size_t size=ZSTD_compress(b.data()+n,b.size()-n,raw.data(),raw.size(),3);
    require(!ZSTD_isError(size),ZSTD_getErrorName(size));b.resize(n+size);
    Bytes check(raw.size());size_t decoded=ZSTD_decompress(check.data(),check.size(),b.data()+n,size);
    require(decoded==raw.size()&&check==raw,"block compression round trip failed");return b;
}
std::pair<long long,std::string> table_digest(sqlite3* db,const std::string& table){
    Query q(db,"SELECT * FROM "+quote(table)+" ORDER BY rowid");SHA256_CTX h;SHA256_Init(&h);long long count=0;
    while(q.step()){
        for(int i=0;i<sqlite3_column_count(q.s);++i){
            Bytes b;int type=sqlite3_column_type(q.s,i);b.push_back(type);
            if(type==SQLITE_INTEGER)u64(b,uint64_t(sqlite3_column_int64(q.s,i)));
            else if(type==SQLITE_FLOAT){double d=sqlite3_column_double(q.s,i);uint64_t v;std::memcpy(&v,&d,8);u64(b,v);}
            else if(type==SQLITE_TEXT||type==SQLITE_BLOB){int n=sqlite3_column_bytes(q.s,i);u64(b,n);auto* p=static_cast<const unsigned char*>(sqlite3_column_blob(q.s,i));if(n)b.insert(b.end(),p,p+n);}
            SHA256_Update(&h,b.data(),b.size());
        }
        ++count;
    }
    std::array<unsigned char,32> digest;SHA256_Final(digest.data(),&h);return {count,hex(digest.data(),32)};
}
uint64_t get64(const Bytes& raw,size_t& pos){require(pos+8<=raw.size(),"truncated integer");uint64_t v=0;for(int i=0;i<8;++i)v|=uint64_t(raw[pos++])<<(8*i);return v;}
uint32_t get32(const Bytes& raw,size_t& pos){require(pos+4<=raw.size(),"truncated length");uint32_t v=0;for(int i=0;i<4;++i)v|=uint32_t(raw[pos++])<<(8*i);return v;}
int verify_only(const char* from,const char* to){
    sqlite3 *source=nullptr,*target=nullptr;
    require(sqlite3_open_v2(from,&source,SQLITE_OPEN_READONLY,nullptr)==SQLITE_OK,"cannot open source");
    require(sqlite3_open_v2(to,&target,SQLITE_OPEN_READONLY,nullptr)==SQLITE_OK,"cannot open target");
    sql(source,"PRAGMA query_only=ON; PRAGMA cache_size=-65536; BEGIN");sql(target,"PRAGMA query_only=ON; PRAGMA cache_size=-65536; BEGIN");
    {Query tables(source,"SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name!='chunks' ORDER BY name");
    while(tables.step()){
        auto name=text(tables.s,0);auto a=table_digest(source,name),b=table_digest(target,name);require(a==b,"table content differs: "+name);
        std::cout<<"{\"event\":\"table_verified\",\"table\":\""<<name<<"\",\"rows\":"<<a.first<<",\"sha256\":\""<<a.second<<"\"}"<<std::endl;
    }}
    Query old(source,"SELECT job_id,first_x,next_x,total_x,capped,evidence FROM chunks ORDER BY job_id,first_x");
    Query saved(target,"SELECT job_id,first_x,next_x,total_x,capped,evidence FROM chunks ORDER BY job_id,first_x");
    long long count=0,blocks=0;SHA256_CTX all;SHA256_Init(&all);auto started=std::chrono::steady_clock::now();
    while(saved.step()){
        const auto* blob=static_cast<const unsigned char*>(sqlite3_column_blob(saved.s,5));int len=sqlite3_column_bytes(saved.s,5);
        require(len>=49&&std::memcmp(blob,"VBFCHN01",8)==0,"stored block header changed");
        uint64_t size=0;for(int i=0;i<8;++i)size|=uint64_t(blob[8+i])<<(8*i);
        require(size>=4&&size<=64*1024*1024,"stored block size invalid");Bytes raw(size);
        require(ZSTD_decompress(raw.data(),size,blob+48,len-48)==size,"stored block decode failed");
        auto h=hash(raw);require(std::memcmp(h.data(),blob+16,32)==0,"stored block digest changed");
        size_t pos=0;auto entries=get32(raw,pos);require(entries>0&&entries<=65536,"invalid row count");
        long long cursor=sqlite3_column_int64(saved.s,1),capped=0;
        for(uint32_t r=0;r<entries;++r){
            require(old.step(),"compact ledger has extra records");std::array<uint64_t,5> fields;
            for(int i=0;i<5;++i){fields[i]=get64(raw,pos);require(sqlite3_column_type(old.s,i)==SQLITE_INTEGER&&fields[i]==uint64_t(sqlite3_column_int64(old.s,i)),"original ledger integer changed");}
            auto bytes=get32(raw,pos);require(pos+bytes<=raw.size(),"truncated evidence");
            require(sqlite3_column_type(old.s,5)==SQLITE_TEXT&&sqlite3_column_bytes(old.s,5)==int(bytes)&&std::memcmp(sqlite3_column_text(old.s,5),raw.data()+pos,bytes)==0,"original proof text changed");pos+=bytes;
            require(fields[0]==uint64_t(sqlite3_column_int64(saved.s,0))&&fields[1]==uint64_t(cursor)&&fields[3]==uint64_t(sqlite3_column_int64(saved.s,3)),"block coverage envelope differs");
            require(fields[2]==fields[1]+1||(entries==1&&fields[1]==1&&fields[2]==1&&fields[3]==0),"invalid coverage step");
            require(fields[4]<=1,"invalid cap");cursor=fields[2];capped|=fields[4];++count;
            if(count%10000000==0){double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();std::cout<<"{\"event\":\"ledger_verification_progress\",\"rows\":"<<count<<",\"seconds\":"<<seconds<<"}"<<std::endl;}
        }
        require(pos==raw.size()&&cursor==sqlite3_column_int64(saved.s,2)&&capped==sqlite3_column_int64(saved.s,4),"block envelope changed");
        SHA256_Update(&all,raw.data()+4,raw.size()-4);++blocks;
    }
    require(!old.step(),"compact ledger is missing original records");
    {Query check(target,"PRAGMA main.integrity_check");require(check.step()&&text(check.s,0)=="ok"&&!check.step(),"target integrity failed");}
    {Query check(target,"PRAGMA main.foreign_key_check");require(!check.step(),"foreign key check failed");}
    std::array<unsigned char,32> digest;SHA256_Final(digest.data(),&all);
    std::cout<<"{\"event\":\"complete\",\"logical_chunk_rows\":"<<count<<",\"packed_blocks\":"<<blocks<<",\"logical_chunks_sha256\":\""<<hex(digest.data(),32)<<"\"}"<<std::endl;
    sql(source,"ROLLBACK");sql(target,"ROLLBACK");sqlite3_close_v2(source);sqlite3_close_v2(target);return 0;
}
int main(int argc,char** argv){
    if(argc==4&&std::string(argv[1])=="--verify"){
        try{return verify_only(argv[2],argv[3]);}catch(const std::exception& e){std::cerr<<e.what()<<std::endl;return 1;}
    }
    if(argc!=3){std::cerr<<"usage: compact_closure_ledger SOURCE.sqlite NEW.sqlite\n";return 2;}
    sqlite3 *source=nullptr,*target=nullptr;
    try{
        int fd=open(argv[2],O_CREAT|O_EXCL|O_WRONLY,0600);require(fd>=0,"output already exists or cannot be created");close(fd);
        require(sqlite3_open_v2(argv[1],&source,SQLITE_OPEN_READONLY,nullptr)==SQLITE_OK,"cannot open source");
        require(sqlite3_open(argv[2],&target)==SQLITE_OK,"cannot open target");
        sql(source,"PRAGMA query_only=ON; BEGIN");sql(target,"PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL; PRAGMA cache_size=-65536; BEGIN IMMEDIATE");
        Query attach(target,"ATTACH DATABASE ? AS old");sqlite3_bind_text(attach.s,1,argv[1],-1,SQLITE_STATIC);attach.step();
        std::vector<std::string> tables,indexes;
        {Query schema(source,"SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type,name");
        while(schema.step()){
            std::string kind=text(schema.s,0),name=text(schema.s,1),ddl=text(schema.s,2);
            if(kind=="table"){sql(target,ddl);tables.push_back(name);}
            else if(kind=="index")indexes.push_back(ddl);
            else require(false,"unsupported schema object "+kind);
        }}
        for(const auto& table:tables)if(table!="chunks"){
            sql(target,"INSERT INTO main."+quote(table)+" SELECT * FROM old."+quote(table)+" ORDER BY rowid");
            auto a=table_digest(source,table),b=table_digest(target,table);require(a==b,"table content differs: "+table);
            std::cout<<"{\"event\":\"table_verified\",\"table\":\""<<table<<"\",\"rows\":"<<a.first<<",\"sha256\":\""<<a.second<<"\"}"<<std::endl;
        }
        Query read(source,"SELECT job_id,first_x,next_x,total_x,capped,evidence FROM chunks ORDER BY job_id,first_x");
        Query insert(target,"INSERT INTO chunks VALUES(?,?,?,?,?,?)");
        Bytes raw(4,0);long long job=-1,first=0,next=0,total=0,capped=0,count=0,blocks=0;int n=0;SHA256_CTX all;SHA256_Init(&all);
        auto started=std::chrono::steady_clock::now();
        auto flush=[&](){
            if(!n)return;for(int i=0;i<4;++i)raw[i]=(n>>(8*i))&255;
            Bytes blob=pack(raw);sqlite3_reset(insert.s);sqlite3_clear_bindings(insert.s);
            sqlite3_bind_int64(insert.s,1,job);sqlite3_bind_int64(insert.s,2,first);sqlite3_bind_int64(insert.s,3,next);
            sqlite3_bind_int64(insert.s,4,total);sqlite3_bind_int64(insert.s,5,capped);sqlite3_bind_blob(insert.s,6,blob.data(),blob.size(),SQLITE_TRANSIENT);insert.step();
            ++blocks;raw.assign(4,0);n=0;
        };
        while(read.step()){
            long long j=sqlite3_column_int64(read.s,0),f=sqlite3_column_int64(read.s,1),end=sqlite3_column_int64(read.s,2),t=sqlite3_column_int64(read.s,3),cap=sqlite3_column_int64(read.s,4);
            require(sqlite3_column_type(read.s,5)==SQLITE_TEXT,"source already contains packed evidence; use its decoder");
            require(end==f+1||(end==f&&f==1&&t==0),"invalid legacy coverage interval");require(cap==0||cap==1,"invalid capped flag");
            if(n&&(j!=job||n==4096||f!=next||t!=total||f==end))flush();
            if(!n){job=j;first=f;total=t;capped=0;}
            Bytes record;for(int i=0;i<5;++i)u64(record,uint64_t(sqlite3_column_int64(read.s,i)));
            int len=sqlite3_column_bytes(read.s,5);u32(record,len);auto* p=sqlite3_column_text(read.s,5);record.insert(record.end(),p,p+len);
            SHA256_Update(&all,record.data(),record.size());raw.insert(raw.end(),record.begin(),record.end());++n;++count;next=end;capped|=cap;
            if(f==end)flush();
            if(count%10000000==0){
                struct statvfs space;require(statvfs(argv[2],&space)==0&&uint64_t(space.f_bavail)*space.f_frsize>uint64_t(10)*1024*1024*1024,"fewer than 10 GiB free");
                double seconds=std::chrono::duration<double>(std::chrono::steady_clock::now()-started).count();
                std::cout<<"{\"event\":\"ledger_progress\",\"rows\":"<<count<<",\"blocks\":"<<blocks<<",\"seconds\":"<<seconds<<"}"<<std::endl;
            }
        }
        flush();std::array<unsigned char,32> digest;SHA256_Final(digest.data(),&all);
        for(const auto& ddl:indexes)sql(target,ddl);
        sql(target,"COMMIT");
        {Query saved(target,"SELECT job_id,first_x,next_x,total_x,capped,evidence FROM chunks ORDER BY job_id,first_x");SHA256_CTX verify;SHA256_Init(&verify);long long restored=0;
        while(saved.step()){
            const auto* blob=static_cast<const unsigned char*>(sqlite3_column_blob(saved.s,5));int len=sqlite3_column_bytes(saved.s,5);
            require(len>=49&&std::memcmp(blob,"VBFCHN01",8)==0,"stored block header changed");
            uint64_t size=0;for(int i=0;i<8;++i)size|=uint64_t(blob[8+i])<<(8*i);
            require(size>=4&&size<=64*1024*1024,"stored block size invalid");Bytes decoded(size);
            require(ZSTD_decompress(decoded.data(),size,blob+48,len-48)==size,"stored block decode failed");
            auto h=hash(decoded);require(std::memcmp(h.data(),blob+16,32)==0,"stored block digest changed");
            uint32_t entries=0;for(int i=0;i<4;++i)entries|=uint32_t(decoded[i])<<(8*i);restored+=entries;
            SHA256_Update(&verify,decoded.data()+4,decoded.size()-4);
        }
        std::array<unsigned char,32> check;SHA256_Final(check.data(),&verify);require(restored==count&&check==digest,"stored logical ledger differs from source");}
        {Query check(target,"PRAGMA main.integrity_check");require(check.step()&&text(check.s,0)=="ok","target integrity check failed");require(!check.step(),"additional integrity errors");}
        {Query check(target,"PRAGMA main.foreign_key_check");require(!check.step(),"target foreign key check failed");}
        std::cout<<"{\"event\":\"complete\",\"logical_chunk_rows\":"<<count<<",\"packed_blocks\":"<<blocks<<",\"logical_chunks_sha256\":\""<<hex(digest.data(),32)<<"\"}"<<std::endl;
        sql(source,"ROLLBACK");sqlite3_close_v2(source);sqlite3_close_v2(target);return 0;
    }catch(const std::exception& e){std::cerr<<e.what()<<std::endl;if(target)sqlite3_close_v2(target);if(source)sqlite3_close_v2(source);return 1;}
}
