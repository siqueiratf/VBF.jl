// c++ -O3 -std=c++17 reduce_closure_store.cpp -lsqlite3 -lzstd -lcrypto -pthread -o reduce_closure_store
// Resumable, storage-only migration. Source is read-only and must be stopped.
#include "closure_reduction_codec.hpp"
#include <sqlite3.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <sys/statvfs.h>
#include <fcntl.h>
#include <unistd.h>
#include <condition_variable>
#include <deque>
#include <filesystem>
#include <fstream>
#include <future>
#include <functional>
#include <iostream>
#include <mutex>
#include <queue>
#include <thread>
#include <unordered_map>
using namespace closure_reduce;
struct Query {
 sqlite3_stmt* s=nullptr;
 Query(sqlite3* db,const std::string& q){need(sqlite3_prepare_v2(db,q.c_str(),-1,&s,nullptr)==SQLITE_OK,sqlite3_errmsg(db));}
 ~Query(){sqlite3_finalize(s);}
 bool step(){auto rc=sqlite3_step(s);need(rc==SQLITE_ROW||rc==SQLITE_DONE,sqlite3_errmsg(sqlite3_db_handle(s)));return rc==SQLITE_ROW;}
 void reset(){sqlite3_reset(s);sqlite3_clear_bindings(s);}
};
void reject_segmented(sqlite3* db){
 Query exists(db,"SELECT 1 FROM sqlite_master WHERE type='table' AND name='closure_evidence_segments'");
 if(exists.step()){
  Query rows(db,"SELECT 1 FROM closure_evidence_segments LIMIT 1");
  need(!rows.step(),"checkpoint has external coverage segments; use closure_export_checkpoint or closure_rehydrate_segments! before this legacy helper");
 }
}
void sql(sqlite3* db,const std::string& q){char* e=nullptr;auto rc=sqlite3_exec(db,q.c_str(),nullptr,nullptr,&e);std::string why=e?e:"";sqlite3_free(e);need(rc==SQLITE_OK,q+": "+why);}
std::string str(sqlite3_stmt* s,int i){auto p=sqlite3_column_text(s,i);return p?std::string(reinterpret_cast<const char*>(p),sqlite3_column_bytes(s,i)):"";}
std::string quote(const std::string& s){std::string r="\"";for(char c:s){r+=c;if(c=='\"')r+=c;}return r+'\"';}
void bind_value(sqlite3_stmt* s,int i,const std::string& v){need(sqlite3_bind_text(s,i,v.data(),v.size(),SQLITE_TRANSIENT)==SQLITE_OK,"bind text failed");}
void bind_value(sqlite3_stmt* s,int i,const Bytes& b){static const unsigned char empty=0;need(sqlite3_bind_blob(s,i,b.empty()?&empty:b.data(),b.size(),SQLITE_TRANSIENT)==SQLITE_OK,"bind blob failed");}
std::string file_text(const std::string& p){std::ifstream f(p,std::ios::binary);need(bool(f),"cannot read "+p);return {std::istreambuf_iterator<char>(f),{}};}
std::string digest(const std::string& s){auto h=sha(Bytes(s.begin(),s.end()));return hex(h.data(),32);}
void replace_all(std::string& s,const std::string& from,const std::string& to){if(from.empty())return;size_t p=0;while((p=s.find(from,p))!=std::string::npos){s.replace(p,from.size(),to);p+=to.size();}}
std::string token(const std::string& s){return "!!vbf:"+s+"!!";}
void cell_hash(SHA256_CTX& h,sqlite3_stmt* s,int i){Bytes b;int type=sqlite3_column_type(s,i);b.push_back(type);if(type==SQLITE_INTEGER)u64(b,sqlite3_column_int64(s,i));else if(type==SQLITE_FLOAT){double d=sqlite3_column_double(s,i);uint64_t v;std::memcpy(&v,&d,8);u64(b,v);}else if(type==SQLITE_TEXT||type==SQLITE_BLOB){int n=sqlite3_column_bytes(s,i);u64(b,n);SHA256_Update(&h,b.data(),b.size());if(n)SHA256_Update(&h,sqlite3_column_blob(s,i),n);return;}SHA256_Update(&h,b.data(),b.size());}
std::pair<uint64_t,std::string> table_hash(sqlite3* db,const std::string& name,bool normalized){
 std::string query="SELECT * FROM "+quote(name)+" ORDER BY rowid";
 if(normalized&&name=="candidates")query="SELECT v.* FROM closure_candidates p JOIN candidates v ON v.id=p.id ORDER BY p.rowid";
 if(normalized&&name=="comparisons")query="SELECT * FROM comparisons ORDER BY id";
 Query q(db,query);SHA256_CTX h;SHA256_Init(&h);uint64_t n=0;while(q.step()){for(int i=0;i<sqlite3_column_count(q.s);++i)cell_hash(h,q.s,i);++n;}std::array<unsigned char,32> out;SHA256_Final(out.data(),&h);return {n,hex(out.data(),32)};
}
struct Pool {
 std::vector<std::thread> workers;std::queue<std::function<void()>> queue;std::mutex mutex;std::condition_variable cv;bool stop=false;
 explicit Pool(int n){for(int i=0;i<n;++i)workers.emplace_back([this]{for(;;){std::function<void()> f;{std::unique_lock<std::mutex> l(mutex);cv.wait(l,[&]{return stop||!queue.empty();});if(queue.empty()&&stop)return;f=std::move(queue.front());queue.pop();}f();}});}
 ~Pool(){{std::lock_guard<std::mutex> l(mutex);stop=true;}cv.notify_all();for(auto& w:workers)w.join();}
 template<class F> auto submit(F f){using R=decltype(f());auto t=std::make_shared<std::packaged_task<R()>>(std::move(f));auto result=t->get_future();{std::lock_guard<std::mutex> l(mutex);queue.emplace([t]{(*t)();});}cv.notify_one();return result;}
};
struct Reducer {
 sqlite3 *source=nullptr,*target=nullptr;int lock_fd=-1;std::string from,to,schema,resume_from;uint64_t reserve,maximum;int threads;
 std::unordered_map<std::string,int64_t> templates;std::unique_ptr<Query> ti,tq;
 Reducer(std::string a,std::string b,std::string c,int workers,uint64_t r,uint64_t m,std::string predecessor=""):from(a),to(b),schema(c),resume_from(predecessor),reserve(r),maximum(m),threads(workers){}
 ~Reducer(){ti.reset();tq.reset();if(source)sqlite3_close_v2(source);if(target)sqlite3_close_v2(target);if(lock_fd>=0)close(lock_fd);}
 std::string state(const std::string& key){Query q(target,"SELECT value FROM closure_reduction_state WHERE key=?");bind_value(q.s,1,key);return q.step()?str(q.s,0):"";}
 void state(const std::string& key,const std::string& value){Query q(target,"INSERT OR REPLACE INTO closure_reduction_state VALUES(?,?)");bind_value(q.s,1,key);bind_value(q.s,2,value);q.step();}
 void disk(){struct statvfs v;need(statvfs(to.c_str(),&v)==0,"cannot measure free disk");need(uint64_t(v.f_bavail)*v.f_frsize>=reserve,"disk reserve reached; migration is resumable");need(std::filesystem::file_size(to)<=maximum,"output size budget reached; migration is resumable");}
 void event(const std::string& e,const std::string& table,uint64_t rows){std::cout<<"{\"event\":\""<<e<<"\",\"table\":\""<<table<<"\",\"rows\":"<<rows<<",\"database_bytes\":"<<std::filesystem::file_size(to)<<"}"<<std::endl;}
 int64_t intern(const std::string& body){auto it=templates.find(body);if(it!=templates.end())return it->second;auto h=sha(Bytes(body.begin(),body.end()));Bytes key(h.begin(),h.end());ti->reset();bind_value(ti->s,1,key);bind_value(ti->s,2,body);ti->step();tq->reset();bind_value(tq->s,1,key);need(tq->step(),"proof template lookup missing");need(str(tq->s,1)==body,"proof-template hash collision: expected "+std::to_string(body.size())+" bytes, found "+std::to_string(str(tq->s,1).size()));auto id=sqlite3_column_int64(tq->s,0);if(templates.size()>=100000)templates.clear();templates.emplace(body,id);return id;}
 void open(){
  struct stat st;need(stat(from.c_str(),&st)==0,"source missing");std::string signature=std::filesystem::canonical(from).string()+":"+std::to_string(st.st_size)+":"+std::to_string(st.st_mtim.tv_sec)+":"+std::to_string(st.st_mtim.tv_nsec);
  for(auto suffix:{"-wal","-journal"})need(!std::filesystem::exists(from+suffix)||std::filesystem::file_size(from+suffix)==0,"source has an active journal");
  need(std::filesystem::exists(std::filesystem::path(from).parent_path()/"STOP"),"source must have STOP marker");
  need(sqlite3_open_v2(from.c_str(),&source,SQLITE_OPEN_READONLY,nullptr)==SQLITE_OK,"cannot open source");sql(source,"PRAGMA query_only=ON; PRAGMA cache_size=-65536; BEGIN");
  reject_segmented(source);
  {Query q(source,"SELECT COUNT(*) FROM jobs WHERE status='running'");need(q.step()&&sqlite3_column_int64(q.s,0)==0,"source has running jobs");}
  {Query q(source,"SELECT COUNT(*) FROM sessions WHERE finished=''");need(q.step()&&sqlite3_column_int64(q.s,0)==0,"source has unfinished sessions");}
  bool exists=std::filesystem::exists(to);if(!exists){int fd=::open(to.c_str(),O_CREAT|O_EXCL|O_WRONLY,0600);need(fd>=0,"cannot create output");close(fd);}
  lock_fd=::open(to.c_str(),O_RDWR);need(lock_fd>=0&&flock(lock_fd,LOCK_EX|LOCK_NB)==0,"another reducer owns output");
  need(sqlite3_open_v2(to.c_str(),&target,SQLITE_OPEN_READWRITE|SQLITE_OPEN_URI,nullptr)==SQLITE_OK,"cannot open target");sql(target,"PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL; PRAGMA cache_size=-131072; PRAGMA temp_store=MEMORY; PRAGMA foreign_keys=OFF");
  {Query page(target,"PRAGMA page_size");need(page.step(),"page size unavailable");sql(target,"PRAGMA max_page_count="+std::to_string(maximum/sqlite3_column_int64(page.s,0)));}
  auto executable_sha=digest(file_text("/proc/self/exe"));
  if(!exists){sql(target,"BEGIN; CREATE TABLE closure_reduction_state(key TEXT PRIMARY KEY,value TEXT NOT NULL)");state("source",signature);state("helper_sha256",executable_sha);state("schema_sha256",digest(file_text(schema)));sql(target,file_text(schema));
   // Retain primary-key constraints for IDs/template interning. Build secondary
   // indexes in one scan after bulk loading, rather than rewriting them per row.
   std::vector<std::pair<std::string,std::string>> deferred;
   {Query indexes(target,"SELECT name,sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL");while(indexes.step())deferred.emplace_back(str(indexes.s,0),str(indexes.s,1));}
   for(const auto& [name,ddl]:deferred){state("index:"+name,ddl);sql(target,"DROP INDEX "+quote(name));}
   Query q(source,"SELECT name,sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");while(q.step()){auto name=str(q.s,0);need(name.rfind("closure_",0)!=0||name=="closure_evidence_segments"||name=="closure_segment_chunks","source is already normalized");if(name=="candidates"||name=="comparisons")continue;auto ddl=str(q.s,1);replace_all(ddl,"REFERENCES candidates(id)","REFERENCES closure_candidates(id)");sql(target,ddl);}sql(target,"COMMIT");
  }
  need(state("source")==signature&&state("schema_sha256")==digest(file_text(schema)),"resume source or schema changed");
  auto previous=state("helper_sha256");
  if(previous!=executable_sha){
   need(resume_from==previous&&resume_from.size()==64&&binary_hex(resume_from),"resume helper changed; explicit verified-stage predecessor required");
   // Tool upgrades cannot resume partially converted data under another codec.
   // Every original table and ledger must already have its complete proof.
   {Query tables(source,"SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");while(tables.step()){auto name=str(tables.s,0);need(state(name+":done")=="true"&&state(name+":sha256").size()==64,"helper upgrade requires all scientific tables and ledger already verified");}}
   need(!state("chunks:logical_rows").empty(),"missing ledger proof");
   sql(target,"BEGIN");state("helper_history:"+previous,"all data verified; resumed final database checks with "+executable_sha);state("helper_sha256",executable_sha);state("complete","false");sql(target,"COMMIT");
   std::cout<<"{\"event\":\"verified_stage_helper_upgrade\",\"previous_sha256\":\""<<previous<<"\",\"current_sha256\":\""<<executable_sha<<"\"}"<<std::endl;
  }
  disk();
  {Query q(target,"ATTACH DATABASE ? AS old");bind_value(q.s,1,"file:"+from+"?mode=ro");q.step();}
  ti=std::make_unique<Query>(target,"INSERT OR IGNORE INTO closure_templates(digest,body) VALUES(?,?)");tq=std::make_unique<Query>(target,"SELECT id,body FROM closure_templates WHERE digest=?");
 }
 void verified(const std::string& table){
  auto a=table_hash(source,table,false),b=table_hash(target,table,true);need(a==b,"logical table content differs: "+table);state(table+":sha256",a.second);state(table+":done","true");
  std::cout<<"{\"event\":\"table_verified\",\"table\":\""<<table<<"\",\"rows\":"<<a.first<<",\"sha256\":\""<<a.second<<"\"}"<<std::endl;
 }
 void candidates(){
  const std::string name="candidates";if(state(name+":done")=="true")return;auto last=state(name+":last");int64_t cursor=last.empty()?0:std::stoll(last);
  Query q(source,"SELECT rowid,* FROM candidates WHERE rowid>? ORDER BY rowid");sqlite3_bind_int64(q.s,1,cursor);Query ins(target,"INSERT INTO closure_candidates(rowid,id,lut,lut_text,sigma,apn,degree,template_id,ortho,encoding,class_id,state) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)");
  sql(target,"BEGIN");int n=0;
  while(q.step()){
   cursor=sqlite3_column_int64(q.s,0);auto id=str(q.s,1),lut=str(q.s,2),sigma=str(q.s,3),original=str(q.s,6),body=original,ortho=std::string();bool encode=body.find("!!vbf:")==std::string::npos;
   auto prefix=std::string("ortho_lut_hex = \"");size_t p=body.find(prefix);if(p!=std::string::npos&&(p==0||body[p-1]=='\n')){size_t end=body.find('"',p+prefix.size());need(end!=std::string::npos,"unterminated ortho property");ortho=body.substr(p+prefix.size(),end-p-prefix.size());encode=encode&&binary_hex(ortho);}
   if(encode){replace_all(body,lut,token("c:lut"));replace_all(body,id,token("c:id"));replace_all(body,sigma,token("c:sigma"));replace_all(body,ortho,token("c:ortho"));}else ortho.clear();
   auto tid=intern(body);ins.reset();sqlite3_bind_int64(ins.s,1,cursor);bind_value(ins.s,2,id);if(binary_hex(lut))bind_value(ins.s,3,unhex(lut));else bind_value(ins.s,4,lut);sqlite3_bind_value(ins.s,5,sqlite3_column_value(q.s,3));sqlite3_bind_value(ins.s,6,sqlite3_column_value(q.s,4));sqlite3_bind_value(ins.s,7,sqlite3_column_value(q.s,5));sqlite3_bind_int64(ins.s,8,tid);bind_value(ins.s,9,unhex(ortho));sqlite3_bind_int(ins.s,10,encode);sqlite3_bind_value(ins.s,11,sqlite3_column_value(q.s,7));sqlite3_bind_value(ins.s,12,sqlite3_column_value(q.s,8));ins.step();
   if(++n%10000==0){state(name+":last",std::to_string(cursor));sql(target,"COMMIT");disk();if(n%100000==0)event("copy_progress",name,cursor);sql(target,"BEGIN");}
  }
  state(name+":last",std::to_string(cursor));sql(target,"COMMIT");verified(name);
 }
 void comparisons(){
  const std::string name="comparisons";if(state(name+":done")=="true")return;auto last=state(name+":last");int64_t cursor=last.empty()?0:std::stoll(last);
  Query q(source,"SELECT e.*,a.lut_hex,b.lut_hex,b.id FROM comparisons e JOIN candidates a ON a.id=e.candidate_id JOIN parents p ON p.id=e.target_parent JOIN candidates b ON b.id=p.candidate_id WHERE e.id>? ORDER BY e.id");sqlite3_bind_int64(q.s,1,cursor);
  Query ins(target,"INSERT INTO closure_comparisons VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");sql(target,"BEGIN");int n=0;
  const std::array<std::string,9> keys={"graph_map_columns","graph_map_constant","nodes","seconds","timeout_seconds","max_nodes","stop","evidence","rng_seed"};
  while(q.step()){
   cursor=sqlite3_column_int64(q.s,0);auto body=str(q.s,4);bool encode=body.find("!!vbf:")==std::string::npos;std::array<std::string,9> slots{};
   std::array<std::string,4> values={str(q.s,6),str(q.s,7),str(q.s,1),str(q.s,8)};const std::array<std::string,4> fields={"candidate_lut_hex","target_lut_hex","candidate_sha256","target_sha256"};const std::array<std::string,4> tokens={"c:lut","t:lut","c:id","t:id"};
   for(int i=0;i<4;++i){auto line=fields[i]+" = \""+values[i]+"\"\n";auto p=body.find(line);encode=encode&&p!=std::string::npos&&(p==0||body[p-1]=='\n');}
   if(encode){for(int i=0;i<4;++i)replace_all(body,values[i],token(tokens[i]));for(int i=0;i<9;++i){auto key=keys[i]+" = ";auto p=body.rfind(key,0)==0?0:body.find("\n"+key);if(p!=std::string::npos){if(p!=0)++p;if(body.find("\n"+key,p+key.size())!=std::string::npos)continue;auto end=body.find('\n',p+key.size());if(end!=std::string::npos){slots[i]=body.substr(p+key.size(),end-p-key.size());body.replace(p+key.size(),end-p-key.size(),token("v"+std::to_string(i)));}}}}
   auto tid=intern(body);ins.reset();for(int i=0;i<4;++i)sqlite3_bind_value(ins.s,i+1,sqlite3_column_value(q.s,i));sqlite3_bind_int64(ins.s,5,tid);sqlite3_bind_value(ins.s,6,sqlite3_column_value(q.s,5));sqlite3_bind_int(ins.s,7,encode);for(int i=0;i<9;++i)bind_value(ins.s,8+i,slots[i]);ins.step();
   if(++n%10000==0){state(name+":last",std::to_string(cursor));sql(target,"COMMIT");disk();if(n%100000==0)event("copy_progress",name,cursor);sql(target,"BEGIN");}
  }
  state(name+":last",std::to_string(cursor));sql(target,"COMMIT");verified(name);
 }
 void plain(const std::string& name){
  if(state(name+":done")=="true")return;int64_t cursor=state(name+":last").empty()?0:std::stoll(state(name+":last"));
  for(;;){Query q(source,"SELECT max(rowid),count(*) FROM (SELECT rowid FROM "+quote(name)+" WHERE rowid>? ORDER BY rowid LIMIT 100000)");sqlite3_bind_int64(q.s,1,cursor);q.step();if(sqlite3_column_int64(q.s,1)==0)break;auto end=sqlite3_column_int64(q.s,0);
   sql(target,"BEGIN; INSERT INTO main."+quote(name)+"(rowid,"+columns(name)+") SELECT rowid,* FROM old."+quote(name)+" WHERE rowid>"+std::to_string(cursor)+" AND rowid<="+std::to_string(end)+" ORDER BY rowid");cursor=end;state(name+":last",std::to_string(cursor));sql(target,"COMMIT");disk();if(cursor%1000000==0)event("copy_progress",name,cursor);
  }verified(name);
 }
 std::string columns(const std::string& name){Query q(source,"PRAGMA table_info("+quote(name)+")");std::string s;while(q.step()){if(!s.empty())s+=",";s+=quote(str(q.s,1));}return s;}
 struct Block {int64_t rowid;Envelope envelope;bool text;std::future<Converted> result;};
 void chunks(){
  const std::string name="chunks";if(state(name+":done")=="true")return;int64_t cursor=state(name+":last").empty()?0:std::stoll(state(name+":last"));
  Pool pool(threads);std::deque<Block> queue;Query q(source,"SELECT rowid,* FROM chunks WHERE rowid>? ORDER BY rowid");sqlite3_bind_int64(q.s,1,cursor);Query ins(target,"INSERT INTO chunks(rowid,job_id,first_x,next_x,total_x,capped,evidence) VALUES(?,?,?,?,?,?,?)");int n=0;uint64_t logical=0;
  sql(target,"BEGIN");
  auto flush=[&]{auto item=std::move(queue.front());queue.pop_front();auto value=item.result.get();ins.reset();sqlite3_bind_int64(ins.s,1,item.rowid);const auto& e=item.envelope;uint64_t a[]={e.job,e.first,e.next,e.total,e.cap};for(int i=0;i<5;++i)sqlite3_bind_int64(ins.s,i+2,a[i]);if(item.text)bind_value(ins.s,7,std::string(value.blob.begin(),value.blob.end()));else bind_value(ins.s,7,value.blob);ins.step();cursor=item.rowid;logical+=value.rows;
   if(++n%64==0){state(name+":last",std::to_string(cursor));sql(target,"COMMIT");disk();if(n%1024==0)event("copy_progress",name,cursor);sql(target,"BEGIN");}};
  while(q.step()){
   Envelope e;uint64_t* a[]={&e.job,&e.first,&e.next,&e.total,&e.cap};for(int i=0;i<5;++i)*a[i]=sqlite3_column_int64(q.s,i+1);auto id=sqlite3_column_int64(q.s,0);bool text=sqlite3_column_type(q.s,6)==SQLITE_TEXT;need(text||sqlite3_column_type(q.s,6)==SQLITE_BLOB,"invalid ledger storage type");auto p=static_cast<const unsigned char*>(sqlite3_column_blob(q.s,6));Bytes b(p,p+sqlite3_column_bytes(q.s,6));queue.push_back({id,e,text,pool.submit([b=std::move(b),e,text]{if(text){need(e.cap<=1&&(e.next==e.first+1||(e.first==1&&e.next==1&&e.total==0)),"invalid text coverage");return Converted{b,1,false};}return convert(b,e);})});if(queue.size()>=size_t(threads*2))flush();
  }
  while(!queue.empty())flush();state(name+":last",std::to_string(cursor));sql(target,"COMMIT");verify_chunks();state(name+":done","true");
 }
 void verify_chunks(){
  Query old(source,"SELECT * FROM chunks ORDER BY rowid"),saved(target,"SELECT * FROM chunks ORDER BY rowid");Pool pool(threads);std::deque<std::future<Converted>> queue;uint64_t blocks=0,logical=0;SHA256_CTX h;SHA256_Init(&h);
  auto flush=[&]{auto v=queue.front().get();logical+=v.rows;queue.pop_front();};
  while(saved.step()){
   need(old.step(),"extra chunk block");Envelope e;uint64_t* a[]={&e.job,&e.first,&e.next,&e.total,&e.cap};for(int i=0;i<5;++i){need(sqlite3_column_int64(old.s,i)==sqlite3_column_int64(saved.s,i),"chunk envelope changed");*a[i]=sqlite3_column_int64(saved.s,i);cell_hash(h,saved.s,i);}
   auto p=static_cast<const unsigned char*>(sqlite3_column_blob(saved.s,5));Bytes b(p,p+sqlite3_column_bytes(saved.s,5));if(sqlite3_column_type(saved.s,5)==SQLITE_TEXT){need(sqlite3_column_type(old.s,5)==SQLITE_TEXT&&str(old.s,5)==str(saved.s,5),"legacy text evidence changed");cell_hash(h,saved.s,5);++logical;++blocks;continue;}auto a0=static_cast<const unsigned char*>(sqlite3_column_blob(old.s,5));need(b.size()>=49&&sqlite3_column_bytes(old.s,5)>=49&&std::memcmp(b.data()+8,a0+8,40)==0,"original ledger length or digest changed");SHA256_Update(&h,b.data()+8,40);queue.push_back(pool.submit([b=std::move(b),e]{return convert(b,e);}));if(queue.size()>=size_t(threads*2))flush();if(++blocks%8192==0)event("verify_progress","chunks",blocks);
  }
  while(!queue.empty())flush();need(!old.step(),"missing chunk blocks");std::array<unsigned char,32> out;SHA256_Final(out.data(),&h);state("chunks:logical_rows",std::to_string(logical));state("chunks:sha256",hex(out.data(),32));
  std::cout<<"{\"event\":\"ledger_verified\",\"blocks\":"<<blocks<<",\"logical_rows\":"<<logical<<",\"envelope_digest_sha256\":\""<<hex(out.data(),32)<<"\"}"<<std::endl;
 }
 void run(){
  open();if(state("complete")=="true"){event("already_complete","",0);return;}
  candidates();
  Query tables(source,"SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT IN ('candidates','comparisons','chunks') ORDER BY name");while(tables.step())plain(str(tables.s,0));
  comparisons();chunks();
  Query indexes(source,"SELECT name,sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL ORDER BY name");while(indexes.step()){auto name=str(indexes.s,0);if(name.rfind("candidates_",0)==0||name.rfind("comparisons_",0)==0)continue;auto ddl=str(indexes.s,1);replace_all(ddl,"CREATE INDEX ","CREATE INDEX IF NOT EXISTS ");sql(target,ddl);disk();event("index_created",name,0);}
  std::vector<std::pair<std::string,std::string>> deferred;
  {Query indexes(target,"SELECT key,value FROM closure_reduction_state WHERE key LIKE 'index:%' ORDER BY key");while(indexes.step())deferred.emplace_back(str(indexes.s,0).substr(6),str(indexes.s,1));}
  for(auto [name,ddl]:deferred){replace_all(ddl,"CREATE INDEX ","CREATE INDEX IF NOT EXISTS ");replace_all(ddl,"CREATE UNIQUE INDEX ","CREATE UNIQUE INDEX IF NOT EXISTS ");sql(target,ddl);disk();event("index_created",name,0);}
  {Query check(target,"PRAGMA main.integrity_check");need(check.step()&&str(check.s,0)=="ok"&&!check.step(),"target integrity_check failed");}
  {Query check(target,"PRAGMA main.foreign_key_check");need(!check.step(),"target foreign_key_check failed");}
  state("complete","true");event("complete","",std::stoull(state("chunks:logical_rows")));
 }
};
int main(int argc,char** argv){
 if(argc<4||argc>8){std::cerr<<"usage: reduce_closure_store SOURCE.sqlite NEW.sqlite NORMALIZED.sql [threads=8] [reserve_bytes=12884901888] [max_bytes=59055800320] [verified_stage_predecessor_sha256]\n";return 2;}
 try{int n=argc>4?std::stoi(argv[4]):8;need(n>=1&&n<=32,"threads must be 1..32");Reducer r(argv[1],argv[2],argv[3],n,argc>5?std::stoull(argv[5]):uint64_t(12)<<30,argc>6?std::stoull(argv[6]):uint64_t(55)<<30,argc>7?argv[7]:"");r.run();return 0;}catch(const std::exception& e){std::cerr<<e.what()<<std::endl;return 1;}
}
