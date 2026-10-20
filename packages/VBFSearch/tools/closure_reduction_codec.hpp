// Wire-format companion to src/closure_ledger_v2.jl. Storage only.
#pragma once
#include <zstd.h>
#include <openssl/sha.h>
#include <array>
#include <charconv>
#include <cstring>
#include <limits>
#include <map>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>
namespace closure_reduce {
using Bytes=std::vector<unsigned char>;
inline void need(bool ok,const std::string& why){if(!ok)throw std::runtime_error(why);}
inline void u32(Bytes& b,uint32_t v){for(int i=0;i<4;++i)b.push_back(v>>(8*i));}
inline void u64(Bytes& b,uint64_t v){for(int i=0;i<8;++i)b.push_back(v>>(8*i));}
inline uint64_t fixed(const Bytes& b,size_t& p,size_t n){need(p+n<=b.size(),"truncated ledger integer");uint64_t v=0;for(size_t i=0;i<n;++i)v|=uint64_t(b[p++])<<(8*i);return v;}
inline void var(Bytes& b,uint64_t v){while(v>=128){b.push_back((v&127)|128);v>>=7;}b.push_back(v);}
inline uint64_t var(const Bytes& b,size_t& p){uint64_t v=0;for(int s=0;s<=63;s+=7){need(p<b.size(),"truncated varint");auto c=b[p++];need(s!=63||c<=1,"varint overflow");v|=uint64_t(c&127)<<s;if(c<128){need(s==0||c!=0,"noncanonical varint");return v;}}throw std::runtime_error("varint overflow");}
inline std::array<unsigned char,32> sha(const Bytes& b){std::array<unsigned char,32> h;SHA256(b.data(),b.size(),h.data());return h;}
inline std::string hex(const unsigned char* p,size_t n){static const char* d="0123456789abcdef";std::string s(2*n,'0');for(size_t i=0;i<n;++i){s[2*i]=d[p[i]>>4];s[2*i+1]=d[p[i]&15];}return s;}
inline bool binary_hex(std::string_view s){if(s.size()%2)return false;for(char c:s)if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))return false;return true;}
inline Bytes unhex(std::string_view s){need(binary_hex(s),"invalid lowercase hex");Bytes b;auto n=[](char c){return c<='9'?c-'0':c-'a'+10;};for(size_t i=0;i<s.size();i+=2)b.push_back(n(s[i])*16+n(s[i+1]));return b;}
inline Bytes decompress(const unsigned char* p,size_t n,size_t maximum){
 auto size=ZSTD_getFrameContentSize(p,n);need(size!=ZSTD_CONTENTSIZE_ERROR,"invalid zstd frame");need(ZSTD_findFrameCompressedSize(p,n)==n,"trailing compressed ledger bytes");
 if(size!=ZSTD_CONTENTSIZE_UNKNOWN){need(size<=maximum,"ledger decompression limit");Bytes b(size);auto rc=ZSTD_decompress(b.data(),b.size(),p,n);need(rc==size,"ledger decompression failed");return b;}
 // CodecZstd's streaming frames need not declare their content size.
 auto stream=ZSTD_createDStream();need(stream!=nullptr,"cannot allocate zstd stream");ZSTD_initDStream(stream);ZSTD_inBuffer in{p,n,0};Bytes result;std::array<unsigned char,131072> buffer;size_t remaining=1;
 try{while(remaining){ZSTD_outBuffer out{buffer.data(),buffer.size(),0};auto before=in.pos;remaining=ZSTD_decompressStream(stream,&out,&in);need(!ZSTD_isError(remaining),"invalid streaming zstd frame");need(result.size()+out.pos<=maximum,"ledger decompression limit");result.insert(result.end(),buffer.begin(),buffer.begin()+out.pos);need(remaining==0||in.pos>before||out.pos>0,"truncated streaming zstd frame");}need(in.pos==n,"trailing streaming frame bytes");}catch(...){ZSTD_freeDStream(stream);throw;}ZSTD_freeDStream(stream);return result;
}
inline Bytes compress(const Bytes& raw){Bytes b(ZSTD_compressBound(raw.size()));auto n=ZSTD_compress(b.data(),b.size(),raw.data(),raw.size(),3);need(!ZSTD_isError(n),ZSTD_getErrorName(n));b.resize(n);return b;}
inline void number(std::string& s,uint64_t v){char b[32];auto r=std::to_chars(b,b+32,v);s.append(b,r.ptr);}
using Outcome=std::array<uint64_t,5>;
inline std::string proof(const std::array<uint32_t,5>& forms,uint64_t first,uint64_t total,uint64_t rep,const Outcome& v){
 std::string s;s.reserve(512);s="V5_forms = [";for(int i=0;i<5;++i){if(i)s+=", ";number(s,forms[i]);}s+="]\ncandidate_spaces = ";number(s,v[0]);s+="\ncapped = ";s+=v[4]?"true":"false";s+="\ncompletion_spaces = ";number(s,v[1]);s+="\ncoset_order = \"increasing nonzero quotient integer with exact bent count\"\ncoset_representative = ";number(s,rep);s+="\ndu_reject = ";number(s,v[2]);s+="\nfirst_x = ";number(s,first);s+="\nheuristic_pruning = false\nlinear_system_candidates = ";number(s,v[3]);s+="\nnext_x = ";number(s,first+1);s+="\ntotal_x = ";number(s,total);s+='\n';return s;
}
struct Parser {
 std::string_view s;size_t p=0;
 bool lit(std::string_view x){if(s.substr(p,x.size())!=x)return false;p+=x.size();return true;}
 bool num(uint64_t& v){auto a=s.data()+p;auto r=std::from_chars(a,s.data()+s.size(),v);if(r.ec!=std::errc()||r.ptr==a)return false;p=r.ptr-s.data();return true;}
};
inline bool parse_proof(std::string_view s,std::array<uint32_t,5>& forms,uint64_t first,uint64_t total,uint64_t& rep,Outcome& v){
 Parser p{s};uint64_t x=0;if(!p.lit("V5_forms = ["))return false;
 for(int i=0;i<5;++i){if(i&&!p.lit(", "))return false;if(!p.num(x)||x>UINT32_MAX)return false;forms[i]=x;}
 if(!p.lit("]\ncandidate_spaces = ")||!p.num(v[0])||!p.lit("\ncapped = "))return false;
 if(p.lit("true"))v[4]=1;else if(p.lit("false"))v[4]=0;else return false;
 if(!p.lit("\ncompletion_spaces = ")||!p.num(v[1])||!p.lit("\ncoset_order = \"increasing nonzero quotient integer with exact bent count\"\ncoset_representative = ")||!p.num(rep)||!p.lit("\ndu_reject = ")||!p.num(v[2])||!p.lit("\nfirst_x = ")||!p.num(x)||x!=first||!p.lit("\nheuristic_pruning = false\nlinear_system_candidates = ")||!p.num(v[3])||!p.lit("\nnext_x = ")||!p.num(x)||x!=first+1||!p.lit("\ntotal_x = ")||!p.num(x)||x!=total||!p.lit("\n")||p.p!=s.size())return false;
 for(auto a:v)if(a>INT64_MAX)return false;
 return rep<=INT64_MAX&&proof(forms,first,total,rep,v)==s;
}
inline Bytes restore_v2(const Bytes& b,size_t raw_size){
 size_t p=0;auto job=fixed(b,p,8),first=fixed(b,p,8),total=fixed(b,p,8);std::array<uint32_t,5> forms;for(auto& x:forms)x=fixed(b,p,4);
 auto n=fixed(b,p,4),nt=fixed(b,p,4);need(nt>=1&&nt<=n&&n<=65536&&first<=uint64_t(INT64_MAX)-n&&job<=INT64_MAX&&total<=INT64_MAX,"invalid V2 context");
 std::vector<Outcome> templates(nt);for(auto& v:templates){for(auto& x:v){x=var(b,p);need(x<=INT64_MAX,"outcome overflow");}need(v[4]<=1,"invalid cap");}
 Bytes out;out.reserve(raw_size);u32(out,n);__int128 previous=0;
 for(uint64_t i=0;i<n;++i){auto z=var(b,p),idx=var(b,p);previous+=(z&1)?-__int128(z>>1)-1:__int128(z>>1);need(previous>=0&&previous<=INT64_MAX&&idx<nt,"invalid representative or template");auto& v=templates[idx];auto s=proof(forms,first+i,total,uint64_t(previous),v);u64(out,job);u64(out,first+i);u64(out,first+i+1);u64(out,total);u64(out,v[4]);u32(out,s.size());out.insert(out.end(),s.begin(),s.end());need(out.size()<=raw_size,"V2 logical length overflow");}
 need(p==b.size()&&out.size()==raw_size,"V2 logical size or trailing bytes");return out;
}
struct Envelope{uint64_t job,first,next,total,cap;};
struct Converted{Bytes blob;uint64_t rows=0;bool normalized=false;};
inline Converted convert(const Bytes& blob,const Envelope& e){
 need(blob.size()>=49&&(std::memcmp(blob.data(),"VBFCHN01",8)==0||std::memcmp(blob.data(),"VBFCHN02",8)==0),"unknown ledger encoding");
 size_t p=8;auto raw_size=fixed(blob,p,8);need(raw_size>=4&&raw_size<=64*1024*1024,"invalid logical ledger size");
 auto packed=decompress(blob.data()+48,blob.size()-48,64*1024*1024);bool v2=blob[7]=='2';Bytes raw=v2?restore_v2(packed,raw_size):std::move(packed);need(raw.size()==raw_size,"V1 logical size mismatch");auto digest=sha(raw);need(std::memcmp(blob.data()+16,digest.data(),32)==0,"ledger SHA-256 mismatch");
 p=0;auto n=fixed(raw,p,4);need(n>=1&&n<=65536,"invalid ledger count");std::array<uint32_t,5> forms0{};std::vector<Outcome> templates;std::map<Outcome,uint64_t> intern;std::vector<std::pair<uint64_t,uint64_t>> entries;bool canonical=!v2;uint64_t capped=0,cursor=e.first;
 for(uint64_t i=0;i<n;++i){auto job=fixed(raw,p,8),first=fixed(raw,p,8),next=fixed(raw,p,8),total=fixed(raw,p,8),cap=fixed(raw,p,8),len=fixed(raw,p,4);need(p+len<=raw.size(),"truncated legacy proof");need(job==e.job&&first==cursor&&total==e.total&&cap<=1&&(next==first+1||(n==1&&first==1&&next==1&&total==0)),"ledger coverage mismatch");cursor=next;capped|=cap;
 if(canonical){std::array<uint32_t,5> forms;Outcome values;uint64_t rep=0;canonical=next==first+1&&parse_proof(std::string_view(reinterpret_cast<const char*>(raw.data()+p),len),forms,first,total,rep,values)&&values[4]==cap;if(canonical){if(i==0)forms0=forms;canonical=forms==forms0;if(canonical){auto it=intern.find(values);uint64_t idx=it==intern.end()?templates.size():it->second;if(it==intern.end()){templates.push_back(values);intern.emplace(values,idx);}entries.emplace_back(rep,idx);}}}p+=len;
 }
 need(p==raw.size()&&cursor==e.next&&capped==e.cap,"ledger envelope mismatch");
 if(!canonical)return {blob,n,v2};
 Bytes normalized;u64(normalized,e.job);u64(normalized,e.first);u64(normalized,e.total);for(auto x:forms0)u32(normalized,x);u32(normalized,n);u32(normalized,templates.size());for(auto& v:templates)for(auto x:v)var(normalized,x);int64_t prev=0;
 for(auto [rep,idx]:entries){__int128 delta=__int128(rep)-prev;prev=rep;var(normalized,uint64_t(delta>=0?delta*2:-delta*2-1));var(normalized,idx);}
 auto z=compress(normalized);auto decoded=decompress(z.data(),z.size(),64*1024*1024);need(restore_v2(decoded,raw_size)==raw,"V2 byte-exact roundtrip failed");
 Bytes out={'V','B','F','C','H','N','0','2'};u64(out,raw_size);out.insert(out.end(),digest.begin(),digest.end());out.insert(out.end(),z.begin(),z.end());return {std::move(out),n,true};
}
} // namespace
