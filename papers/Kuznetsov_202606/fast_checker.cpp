#include <iostream>
#include <fstream>
#include <vector>
#include <set>
#include <map>
#include <string>
#include <omp.h>
#include <chrono>
#include <algorithm>
#include <cstdlib>

using namespace std;

void fwht(int* data, int n) {
    for (int len = 1; len < n; len <<= 1) {
        for (int i = 0; i < n; i += 2 * len) {
            for (int j = 0; j < len; j++) {
                int u = data[i + j];
                int v = data[i + len + j];
                data[i + j] = u + v;
                data[i + len + j] = u - v;
            }
        }
    }
}

int main(int argc, char** argv) {
    // usage: fast_checker [basis_rows.bin] [n_free] [found_apns.txt] [apn_classes.txt]
    // n=8 classifier; signature catalog below = Kuznetsov's 6 classes (A-F).
    string basis_path = argc > 1 ? argv[1] : "basis_n8_c22_rows.bin";
    int    n_free     = argc > 2 ? atoi(argv[2]) : 40;
    string in_path    = argc > 3 ? argv[3] : "found_apns.txt";
    string out_path   = argc > 4 ? argv[4] : "apn_classes.txt";

    vector<uint64_t> basis(n_free * 8);
    ifstream b_in(basis_path, ios::binary);
    if (!b_in) { cerr << "cannot open basis: " << basis_path << endl; return 1; }
    b_in.read((char*)basis.data(), (streamsize)n_free * 8 * 8);
    b_in.close();

    ifstream apn_in(in_path);
    if (!apn_in) { cerr << "cannot open input: " << in_path << endl; return 1; }

    ofstream out_classes(out_path);

    map<vector<int>, char> known_sigs_map;
    known_sigs_map[{0,39600,2,19680,4,5220,6,600,8,180,-1,0,14520,8,22500,16,14360,24,9060,32,3595,40,1080,48,420}] = 'A';
    known_sigs_map[{0,38592,2,21426,4,4590,6,654,8,18,-1,0,12417,8,23208,16,16346,24,8400,32,3910,40,1008,48,222,56,24}] = 'B';
    known_sigs_map[{0,38004,2,22614,4,4008,6,630,10,24,-1,0,12363,8,22776,16,16646,24,8856,32,3652,40,1008,48,234}] = 'C';
    known_sigs_map[{0,37980,2,22272,4,4716,6,312,-1,0,12267,8,22920,16,16340,24,8928,32,4084,40,792,48,204}] = 'D';
    known_sigs_map[{0,39780,2,21930,6,3570,-1,0,10455,8,26520,16,18530,24,4080,32,3400,40,2040,48,510}] = 'E';
    known_sigs_map[{0,35700,2,26520,4,3060,-1,0,12495,8,22440,16,14960,24,10200,32,5440}] = 'F';

    set<vector<int>> known_sigs;
    uint64_t total_checked = 0;
    
    const int CHUNK_SIZE = 100000;
    vector<uint64_t> apns(CHUNK_SIZE);
    
    auto start = chrono::high_resolution_clock::now();

    while (true) {
        int read_count = 0;
        string line;
        while (read_count < CHUNK_SIZE && getline(apn_in, line)) {
            if (line.empty()) continue;
            apns[read_count++] = stoull(line);
        }
        if (read_count == 0) break;
        
        vector<char> local_classes(read_count);
        
        #pragma omp parallel for
        for (int i = 0; i < read_count; i++) {
            uint64_t sample = apns[i];
            
            uint64_t row[8] = {0};
            for (int bit = 0; bit < n_free; bit++) {
                if ((sample >> bit) & 1) {
                    for (int r = 0; r < 8; r++) {
                        row[r] ^= basis[bit * 8 + r];
                    }
                }
            }
            
            uint8_t pi[256];
            pi[0] = 0;
            for (int a = 1; a < 256; a++) {
                uint64_t matrix_a = 0;
                for (int r = 0; r < 8; r++) {
                    if ((a >> r) & 1) matrix_a ^= row[r];
                }
                
                uint32_t cols[8];
                for (int c = 0; c < 8; c++) cols[c] = (matrix_a >> (c * 8)) & 0xFF;
                
                uint8_t y_found = 0;
                for (uint32_t y = 1; y < 256; y++) {
                    bool ok = true;
                    for (int c = 0; c < 8; c++) {
                        if (__builtin_parity(y & cols[c])) { ok = false; break; }
                    }
                    if (ok) {
                        y_found = y; 
                        break;
                    }
                }
                pi[a] = y_found;
            }
            
            map<int, int> diff_sp;
            int counts[256][256] = {0};
            for (int a = 1; a < 256; a++) {
                for (int x = 0; x < 256; x++) {
                    counts[a][pi[x] ^ pi[x^a]]++;
                }
            }
            for (int a = 1; a < 256; a++) {
                for (int b = 0; b < 256; b++) {
                    diff_sp[counts[a][b]]++;
                }
            }
            
            map<int, int> walsh_sp;
            for (int v = 1; v < 256; v++) {
                int w[256];
                for (int x = 0; x < 256; x++) {
                    w[x] = __builtin_parity(v & pi[x]) ? -1 : 1;
                }
                fwht(w, 256);
                for (int u = 0; u < 256; u++) {
                    walsh_sp[abs(w[u])]++;
                }
            }
            
            walsh_sp[0] += 255;
            
            vector<int> sig;
            for (auto const& p : diff_sp) { sig.push_back(p.first); sig.push_back(p.second); }
            sig.push_back(-1);
            for (auto const& p : walsh_sp) { sig.push_back(p.first); sig.push_back(p.second); }
            
            auto it = known_sigs_map.find(sig);
            if (it != known_sigs_map.end()) {
                local_classes[i] = it->second;
            } else {
                local_classes[i] = '?';
                #pragma omp critical
                {
                    cout << "Unmatched sig: ";
                    for (int x : sig) cout << x << ",";
                    cout << endl;
                }
            }
        }
        
        for (int i = 0; i < read_count; i++) {
            out_classes << local_classes[i] << '\n';
        }
        
        total_checked += read_count;
        if (total_checked % 1000000 == 0 || total_checked == 97920000) {
            auto now = chrono::high_resolution_clock::now();
            double elapsed = chrono::duration<double>(now - start).count();
            cout << "Checked " << total_checked << " APNs in " << elapsed << " s (" 
                 << (total_checked / elapsed) << " ops/s)" << endl;
        }
    }
    
    out_classes.close();
    return 0;
}
