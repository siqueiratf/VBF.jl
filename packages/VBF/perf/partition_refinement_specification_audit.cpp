// Independent specification probes for the external Kaleyski–Sunde C++ core.
// Compile against the pinned checkout documented in the conformance record.
#include "ccz_auto.h"
#include "ccz_equivalence.h"
#include "partition_branch.h"
#include "refine.h"
#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <vector>

void require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

int main() {
  for (int m : {1, 2}) {
    const auto F = BuildGraph({0, 0, 0, 1}, 2, m);
    PartialAffineMap A(F.d_bits);
    for (int i = 0; i < 3; ++i)
      require(A.Update(F.points[i], F.points[i]), "identity partial update");
    OrderedPartition P(std::vector<OrderedPartition::Cell>{{1}, {2}, {0, 3}});
    const auto cell = partition_branch::NextUndeterminedBranchCell(F, P, P, A);
    require(cell.has_value() && *cell == 2, "sole free point must be eligible");
    require(!A.GetImage(F.points[3]).has_value(), "fourth point must be free");

    RunCCZAuto(F, 64, 10.0);
    require(FoundEntireAutoGroup(), "group search must complete");
    require(GetGraphActionAutoGroup() == 24, "graph group must be S4");
    require(GetTotalAutoGroup() == (m == 1 ? 24 : 192), "ambient kernel order");
    require(RunCCZEquivalence(F, F, {}).has_value(), "positive equivalence");
    std::cout << "n=2,m=" << m << ": sole-free branch accepted; graph order=24; ambient order="
              << GetTotalAutoGroup() << '\n';
  }

  const auto F = BuildGraph({0, 0}, 1, 1);
  const auto floor = std::numeric_limits<std::size_t>::max();
  std::vector<Hyperplane> planes;
  OrderedPartition left, right;
  require(BuildHyperplaneSubsetByWalsh(F, floor, &planes, &left), "build hyperplanes");
  right = left;
  OrderedPartition pl(std::vector<uint32_t>{0, 1}), pr = pl;
  require(planes.size() == 6, "six ambient hyperplanes");
  require(RefineToFixpoint(F, F, planes, planes, &pl, &pr, &left, &right, floor),
          "oversized floor must not overrun");
  require(left.FlattenElementsInCellOrder().size() == 6 && left.HasSameShape(right),
          "oversized floor must retain all hyperplanes");
  std::cout << "n=1,m=1: oversized floor retains all 6 hyperplanes\n";
}
