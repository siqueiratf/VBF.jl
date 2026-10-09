## Hyperplane scan: analysis

Functions: 11684. Pairs (F, H): 2979420. Coset rows (k > 1): 24304.

### Rate of k > 1 per source

| source | functions | pairs | pairs k > 1 | rate | k histogram | functions with n_gt1 > 0 | max n_gt1 | seconds / function |
|---|---:|---:|---:|---:|---|---:|---:|---:|
| catalog | 67 | 17085 | 2602 | 15.2297% | 1:14483 2:1313 3:2 4:1287 | 37 (55.2239%) | 255 | 17.9 |
| edelpott2009_n8 | 22 | 5610 | 693 | 12.3529% | 1:4917 2:432 4:261 | 15 (68.1818%) | 255 | 17.4 |
| wengtangong2013_n8 | 10 | 2550 | 9 | 0.3529% | 1:2541 2:9 | 3 (30.0000%) | 3 | 14.8 |
| taniguchi2019_n8 | 2 | 510 | 0 | 0.0000% | 1:510 | 0 (0.0000%) | 0 | 14.9 |
| beierleleanderperrin2022_n8 | 2256 | 575280 | 290 | 0.0504% | 1:574990 2:290 | 267 (11.8351%) | 4 | 15.7 |
| yuwangli2014_qam_n8 | 2000 | 510000 | 341 | 0.0669% | 1:509659 2:338 4:3 | 265 (13.2500%) | 21 | 14.2 |
| yuperrin2022_qam_n8 | 2000 | 510000 | 299 | 0.0586% | 1:509701 2:299 | 274 (13.7000%) | 4 | 14.1 |
| beierleleander2022_n8 | 2000 | 510000 | 5883 | 1.1535% | 1:504117 2:5858 3:25 | 1242 (62.1000%) | 18 | 14.2 |
| census553 | 553 | 141015 | 80 | 0.0567% | 1:140935 2:79 3:1 | 72 (13.0199%) | 4 | 14.1 |
| extra | 1 | 255 | 1 | 0.3922% | 1:254 2:1 | 1 (100.0000%) | 1 | 14.0 |
| search773 | 773 | 197115 | 114 | 0.0578% | 1:197001 2:114 | 101 (13.0660%) | 4 | 14.1 |
| beierle2025_sample | 2000 | 510000 | 275 | 0.0539% | 1:509725 2:275 | 250 (12.5000%) | 3 | 14.2 |

### Number of hyperplanes with k > 1 per function (value:count)

| source | n_gt1 histogram |
|---|---|
| catalog | 0:30 2:1 3:6 4:1 6:5 7:1 9:1 15:9 21:3 39:1 255:9 |
| edelpott2009_n8 | 0:7 6:4 9:1 15:6 21:1 39:1 255:2 |
| wengtangong2013_n8 | 0:7 3:3 |
| taniguchi2019_n8 | 0:2 |
| beierleleanderperrin2022_n8 | 0:1989 1:251 2:11 3:3 4:2 |
| yuwangli2014_qam_n8 | 0:1735 1:240 2:16 3:6 15:2 21:1 |
| yuperrin2022_qam_n8 | 0:1726 1:251 2:22 4:1 |
| beierleleander2022_n8 | 0:758 1:11 3:729 4:1 6:329 9:132 12:29 15:9 18:2 |
| census553 | 0:481 1:66 2:5 4:1 |
| extra | 1:1 |
| search773 | 0:672 1:90 2:10 4:1 |
| beierle2025_sample | 0:1750 1:228 2:19 3:3 |

### n_gt1 by component rank counts (r8, r6, r4, r2)

| ranks | functions | with n_gt1 > 0 | mean n_gt1 | pair rate k > 1 | n_gt1 values (value:count) |
|---|---:|---:|---:|---:|---|
| (170, 85, 0, 0) | 10308 | 2007 (19.4703%) | 0.785 | 0.3080% | 2:81 3:559 4:7 6:199 7:1 9:63 12:10 15:19 18:1 21:5 39:2 255:11 (top 12) |
| (174, 80, 1, 0) | 1263 | 439 (34.7585%) | 1.559 | 0.6114% | 0:824 1:82 2:3 3:169 6:117 9:54 12:9 15:4 18:1 |
| (178, 75, 2, 0) | 83 | 54 (65.0602%) | 4.060 | 1.5923% | 0:29 1:7 3:15 6:12 9:11 12:7 15:2 |
| (182, 70, 3, 0) | 25 | 22 (88.0000%) | 5.760 | 2.2588% | 0:3 3:6 6:9 9:4 12:3 |
| (186, 65, 4, 0) | 5 | 5 (100.0000%) | 8.400 | 3.2941% | 3:1 6:1 9:2 15:1 |

### n_gt1 by sigma family (indexed sources that contain sigma(F))

| family | functions | with n_gt1 > 0 | mean n_gt1 | pair rate k > 1 | n_gt1 values (value:count) |
|---|---:|---:|---:|---:|---|
| beierleleanderperrin2022_n8 | 2256 | 267 (11.8351%) | 0.129 | 0.0504% | 0:1989 1:251 2:11 3:3 4:2 |
| beierle2025_n8 | 2000 | 250 (12.5000%) | 0.138 | 0.0539% | 0:1750 1:228 2:19 3:3 |
| beierleleander2022_n8 | 2000 | 1242 (62.1000%) | 2.942 | 1.1535% | 0:758 1:11 3:729 4:1 6:329 9:132 12:29 15:9 18:2 |
| yuperrin2022_qam_n8 | 2000 | 274 (13.7000%) | 0.149 | 0.0586% | 0:1726 1:251 2:22 4:1 |
| yuwangli2014_qam_n8 | 1995 | 262 (13.1328%) | 0.145 | 0.0570% | 0:1733 1:240 2:16 3:6 |
| list:search773 | 773 | 101 (13.0660%) | 0.147 | 0.0578% | 0:672 1:90 2:10 4:1 |
| list:census553 | 553 | 72 (13.0199%) | 0.145 | 0.0567% | 0:481 1:66 2:5 4:1 |
| edelpott2009_n8+functions+simonberg_gf4_n8+yuwangli2014_qam_n8 | 53 | 33 (62.2642%) | 60.113 | 23.5738% | 0:20 6:3 15:12 21:5 39:2 255:11 |
| functions+wengtangong2013_n8 | 16 | 6 (37.5000%) | 1.125 | 0.4412% | 0:10 3:6 |
| edelpott2009_n8+functions+yuwangli2014_qam_n8 | 15 | 13 (86.6667%) | 8.600 | 3.3725% | 0:2 6:6 9:2 15:5 |
| beierleleander2022_n8+functions+simonberg_gf4_n8 | 9 | 6 (66.6667%) | 2.444 | 0.9586% | 0:3 2:1 3:3 4:1 7:1 |
| functions+simonberg_gf4_n8+wengtangong2013_n8 | 7 | 0 (0.0000%) | 0.000 | 0.0000% | 0:7 |
| beierleleander2022_n8+functions+simonberg_gf4_n8+taniguchi2019_n8 | 3 | 0 (0.0000%) | 0.000 | 0.0000% | 0:3 |
| beierleleander2022_n8+functions+taniguchi2019_n8 | 2 | 0 (0.0000%) | 0.000 | 0.0000% | 0:2 |
| beierleleander2022_n8+functions | 1 | 0 (0.0000%) | 0.000 | 0.0000% | 0:1 |
| list:extra | 1 | 1 (100.0000%) | 1.000 | 0.3922% | 1:1 |

### n_gt1 by b6 (bent elements of the best 6-dim subspace, P6 bminK)

| b6 | functions | with n_gt1 > 0 | mean n_gt1 | pair rate k > 1 | n_gt1 values (value:count) |
|---|---:|---:|---:|---:|---|
| 54 | 6174 | 858 (13.8970%) | 0.193 | 0.0756% | 0:5316 1:725 2:53 3:50 4:1 6:20 7:1 9:6 12:2 |
| 56 | 2168 | 595 (27.4446%) | 0.989 | 0.3878% | 0:1573 1:165 2:10 3:258 4:3 6:104 9:42 12:8 15:5 |
| 52 | 1954 | 262 (13.4084%) | 0.147 | 0.0578% | 0:1692 1:239 2:21 3:1 4:1 |
| 58 | 1140 | 672 (58.9474%) | 2.790 | 1.0943% | 0:468 1:8 3:394 4:2 6:175 9:69 12:18 15:4 18:2 |
| 60 | 156 | 88 (56.4103%) | 2.891 | 1.1337% | 0:68 1:1 3:41 6:30 9:15 12:1 |
| 50 | 92 | 52 (56.5217%) | 36.228 | 14.2072% | 0:40 3:6 6:9 9:2 15:17 21:5 39:2 255:11 |

### n_gt1 by (b6, K6)

| (b6, K6) | functions | with n_gt1 > 0 | mean n_gt1 | pair rate k > 1 | n_gt1 values (value:count) |
|---|---:|---:|---:|---:|---|
| (54, 90) | 6170 | 858 (13.9060%) | 0.193 | 0.0756% | 0:5312 1:725 2:53 3:50 4:1 6:20 7:1 9:6 12:2 |
| (56, 84) | 2158 | 592 (27.4328%) | 0.988 | 0.3874% | 0:1566 1:165 2:10 3:256 4:3 6:103 9:42 12:8 15:5 |
| (52, 96) | 1954 | 262 (13.4084%) | 0.147 | 0.0578% | 0:1692 1:239 2:21 3:1 4:1 |
| (58, 78) | 1122 | 662 (59.0018%) | 2.800 | 1.0982% | 0:460 1:8 3:387 4:2 6:172 9:69 12:18 15:4 18:2 |
| (60, 72) | 146 | 81 (55.4795%) | 2.856 | 1.1201% | 0:65 3:39 6:27 9:14 12:1 |
| (50, 102) | 92 | 52 (56.5217%) | 36.228 | 14.2072% | 0:40 3:6 6:9 9:2 15:17 21:5 39:2 255:11 |
| (58, 90) | 18 | 10 (55.5556%) | 2.167 | 0.8497% | 0:8 3:7 6:3 |
| (56, 96) | 10 | 3 (30.0000%) | 1.200 | 0.4706% | 0:7 3:2 6:1 |
| (60, 84) | 10 | 7 (70.0000%) | 3.400 | 1.3333% | 0:3 1:1 3:2 6:3 9:1 |
| (54, 102) | 4 | 0 (0.0000%) | 0.000 | 0.0000% | 0:4 |

### Spearman correlation of n_gt1 with invariants

| set | functions | r4 | b6 | K6 | n_gt1 > 0 with 3 \| n_gt1 |
|---|---:|---:|---:|---:|---:|
| all | 11684 | 0.171 | 0.297 | -0.293 | 1297 / 2527 |
| catalog | 67 | 0.003 | -0.258 | 0.258 | 34 / 37 |
| edelpott2009_n8 | 22 | - | -0.483 | 0.483 | 15 / 15 |
| beierleleanderperrin2022_n8 | 2256 | 0.009 | -0.028 | 0.025 | 3 / 267 |
| yuwangli2014_qam_n8 | 2000 | -0.029 | 0.004 | -0.005 | 9 / 265 |
| yuperrin2022_qam_n8 | 2000 | -0.001 | -0.002 | 0.002 | 0 / 274 |
| beierleleander2022_n8 | 2000 | 0.239 | 0.017 | -0.016 | 1230 / 1242 |
| census553 | 553 | 0.021 | 0.008 | -0.013 | 0 / 72 |
| search773 | 773 | -0.017 | -0.007 | 0.007 | 0 / 101 |
| beierle2025_sample | 2000 | -0.044 | -0.030 | 0.029 | 3 / 250 |

### Cosets of pairs with k > 1: status of the extension

| source | pairs k > 1 | pairs with one coset of sigma(F) | cosets | sigma = sigma(F) | other: known | census553 | extra | search773 | raw546 | NEW | distinct other sigma |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| catalog | 2602 | 2579 | 7780 | 2625 | 5152 | 0 | 0 | 0 | 0 | 3 | 26 |
| edelpott2009_n8 | 693 | 681 | 1908 | 705 | 1203 | 0 | 0 | 0 | 0 | 0 | 15 |
| wengtangong2013_n8 | 9 | 9 | 18 | 9 | 6 | 0 | 0 | 0 | 0 | 3 | 3 |
| beierleleanderperrin2022_n8 | 290 | 290 | 580 | 290 | 202 | 0 | 0 | 0 | 0 | 88 | 282 |
| yuwangli2014_qam_n8 | 341 | 335 | 688 | 347 | 244 | 0 | 0 | 0 | 0 | 97 | 289 |
| yuperrin2022_qam_n8 | 299 | 299 | 598 | 299 | 197 | 0 | 0 | 0 | 0 | 102 | 297 |
| beierleleander2022_n8 | 5883 | 5876 | 11791 | 5890 | 5799 | 0 | 0 | 0 | 0 | 102 | 1814 |
| census553 | 80 | 80 | 161 | 80 | 54 | 0 | 0 | 0 | 0 | 27 | 79 |
| extra | 1 | 1 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| search773 | 114 | 111 | 228 | 117 | 74 | 0 | 0 | 0 | 0 | 37 | 111 |
| beierle2025_sample | 275 | 275 | 550 | 275 | 189 | 0 | 0 | 0 | 0 | 86 | 271 |

### Other known extensions: indexed sources of their sigma (distinct sigma per parent source)

| parent source | sigma family of the extension (count) |
|---|---|
| catalog | edelpott2009_n8+functions+simonberg_gf4_n8+yuwangli2014_qam_n8: 9; edelpott2009_n8+functions+yuwangli2014_qam_n8: 6; beierleleander2022_n8+functions+simonberg_gf4_n8: 4; beierleleander2022_n8: 3; functions+wengtangong2013_n8: 2; beierle2025_n8: 1 |
| edelpott2009_n8 | edelpott2009_n8+functions+simonberg_gf4_n8+yuwangli2014_qam_n8: 9; edelpott2009_n8+functions+yuwangli2014_qam_n8: 6 |
| wengtangong2013_n8 | functions+wengtangong2013_n8: 2 |
| beierleleanderperrin2022_n8 | beierle2025_n8: 194; beierleleanderperrin2022_n8: 4 |
| yuwangli2014_qam_n8 | beierle2025_n8: 180; beierleleander2022_n8: 5; edelpott2009_n8+functions+simonberg_gf4_n8+yuwangli2014_qam_n8: 5; edelpott2009_n8+functions+yuwangli2014_qam_n8: 3 |
| yuperrin2022_qam_n8 | beierle2025_n8: 195; yuwangli2014_qam_n8: 1; yuperrin2022_qam_n8: 1 |
| beierleleander2022_n8 | beierleleander2022_n8: 1714; beierle2025_n8: 67; beierleleanderperrin2022_n8: 1 |
| census553 | beierle2025_n8: 51; beierleleanderperrin2022_n8: 1 |
| extra | beierle2025_n8: 1 |
| search773 | beierle2025_n8: 73; yuperrin2022_qam_n8: 1 |
| beierle2025_sample | beierle2025_n8: 184; yuwangli2014_qam_n8: 1 |

### New classes and yield

| source | thread-hours | NEW cosets | distinct NEW sigma (first found here) | NEW per thread-hour |
|---|---:|---:|---:|---:|
| catalog | 0.33 | 3 | 1 | 3.00 |
| edelpott2009_n8 | 0.11 | 0 | 0 | 0.00 |
| wengtangong2013_n8 | 0.04 | 3 | 0 | 0.00 |
| taniguchi2019_n8 | 0.01 | 0 | 0 | 0.00 |
| beierleleanderperrin2022_n8 | 9.82 | 88 | 84 | 8.55 |
| yuwangli2014_qam_n8 | 7.88 | 97 | 96 | 12.18 |
| yuperrin2022_qam_n8 | 7.85 | 102 | 100 | 12.73 |
| beierleleander2022_n8 | 7.90 | 102 | 32 | 4.05 |
| census553 | 2.17 | 27 | 27 | 12.43 |
| extra | 0.00 | 0 | 0 | 0.00 |
| search773 | 3.04 | 37 | 37 | 12.19 |
| beierle2025_sample | 7.87 | 86 | 86 | 10.93 |
| **total** | 47.03 | 545 | 463 | 9.84 |

Thread-hours = sum of the per-function wall times (one function runs on one thread).
Verified NEW classes written to `new_classes_hyperplane.tsv`: 463.
