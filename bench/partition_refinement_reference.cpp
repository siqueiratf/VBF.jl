// Independent benchmark driver for Kaleyski and Sunde's reference implementation.
// No reference source is vendored; compile against an explicit external checkout.
#include "ccz_equivalence.h"
#include "ea_equivalence.h"
#include "partial_map.h"
#include "quadratic.h"
#include <algorithm>
#include <chrono>
#include <iostream>
#include <iomanip>
#include <stdexcept>

int main() {
  std::string name, relation;
  int n, expected, samples;
  while (std::cin >> name >> relation >> n >> expected >> samples) {
    std::vector<uint32_t> f(1u << n), g(1u << n);
    for (auto& x : f) std::cin >> x;
    for (auto& x : g) std::cin >> x;
    std::vector<double> times;
    for (int rep = -1; rep < samples; ++rep) {
      const auto start = std::chrono::steady_clock::now();
      const auto F = BuildGraph(f, n, n), G = BuildGraph(g, n, n);
      // Match Julia's automatic quadratic root symmetry reduction. These
      // translations have trivial point stabilizers; no general group is found.
      std::vector<groups::Permutation> translations;
      BuildQuadraticTranslationGenerators(G, &translations);
      auto result = relation == "ea" ? RunEAEquivalence(F, G, translations)
                                     : RunCCZEquivalence(F, G, translations);
      const double seconds = std::chrono::duration<double>(
          std::chrono::steady_clock::now() - start).count();
      if (bool(result) != bool(expected)) throw std::runtime_error("wrong decision: " + name);
      if (result) {
        PartialAffineMap partial(2 * n);
        for (const auto& pair : *result)
          if (!partial.Update(pair.first, pair.second))
            throw std::runtime_error("inconsistent witness");
        AffineMapData map;
        if (!partial.ExtractRepresentativeAffineMap(&map, relation == "ea" ? n : 0,
                                                    relation == "ea" ? n : 0))
          throw std::runtime_error("cannot complete witness");
        if (map.dimension_bits != 2 * n || map.linear_cols.size() != size_t(2 * n))
          throw std::runtime_error("wrong ambient dimension");
        std::vector<uint32_t> basis(2 * n, 0);
        for (auto col : map.linear_cols) {
          if (col >= (1u << (2 * n))) throw std::runtime_error("invalid linear column");
          auto v = col;
          for (int bit = 2 * n - 1; bit >= 0; --bit) {
            if (!(v & (1u << bit))) continue;
            if (basis[bit]) v ^= basis[bit];
            else { basis[bit] = v; break; }
          }
          if (!v) throw std::runtime_error("singular witness");
        }
        for (auto p : F.points) {
          const auto image = map.Apply(p);
          if (image >= G.is_graph.size() || !G.is_graph[image])
            throw std::runtime_error("wrong graph image");
        }
        if (relation == "ea")
          for (int i = n; i < 2 * n; ++i)
            if (map.linear_cols[i] & ((1u << n) - 1))
              throw std::runtime_error("wrong EA block form");
      }
      if (rep >= 0) times.push_back(seconds);
    }
    std::sort(times.begin(), times.end());
    std::cout << name << ',' << std::setprecision(9) << times[times.size() / 2] << std::endl;
  }
}
