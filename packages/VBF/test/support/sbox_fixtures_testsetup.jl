# Fixed regression vectors, independent of the mutable catalog.
# Sources are recorded beside each LUT; additions are deliberate test coverage changes.
@testsetup module SBoxFixtures
using VBF
export fixture_sbox, fixture_names, fixture_metadata, fixture_apn

const LITERATURE = Dict{String,Vector{UInt8}}(
    # NIST FIPS 197 (2001), Table 4 — Advanced Encryption Standard
    "AES" => UInt8[99, 124, 119, 123, 242, 107, 111, 197, 48, 1, 103, 43, 254, 215, 171, 118, 202, 130, 201, 125, 250, 89, 71, 240, 173, 212, 162, 175, 156, 164, 114, 192, 183, 253, 147, 38, 54, 63, 247, 204, 52, 165, 229, 241, 113, 216, 49, 21, 4, 199, 35, 195, 24, 150, 5, 154, 7, 18, 128, 226, 235, 39, 178, 117, 9, 131, 44, 26, 27, 110, 90, 160, 82, 59, 214, 179, 41, 227, 47, 132, 83, 209, 0, 237, 32, 252, 177, 91, 106, 203, 190, 57, 74, 76, 88, 207, 208, 239, 170, 251, 67, 77, 51, 133, 69, 249, 2, 127, 80, 60, 159, 168, 81, 163, 64, 143, 146, 157, 56, 245, 188, 182, 218, 33, 16, 255, 243, 210, 205, 12, 19, 236, 95, 151, 68, 23, 196, 167, 126, 61, 100, 93, 25, 115, 96, 129, 79, 220, 34, 42, 144, 136, 70, 238, 184, 20, 222, 94, 11, 219, 224, 50, 58, 10, 73, 6, 36, 92, 194, 211, 172, 98, 145, 149, 228, 121, 231, 200, 55, 109, 141, 213, 78, 169, 108, 86, 244, 234, 101, 122, 174, 8, 186, 120, 37, 46, 28, 166, 180, 198, 232, 221, 116, 31, 75, 189, 139, 138, 112, 62, 181, 102, 72, 3, 246, 14, 97, 53, 87, 185, 134, 193, 29, 158, 225, 248, 152, 17, 105, 217, 142, 148, 155, 30, 135, 233, 206, 85, 40, 223, 140, 161, 137, 13, 191, 230, 66, 104, 65, 153, 45, 15, 176, 84, 187, 22],
    # NIST FIPS 197 (2001), Table 6
    "AES_inv" => UInt8[82, 9, 106, 213, 48, 54, 165, 56, 191, 64, 163, 158, 129, 243, 215, 251, 124, 227, 57, 130, 155, 47, 255, 135, 52, 142, 67, 68, 196, 222, 233, 203, 84, 123, 148, 50, 166, 194, 35, 61, 238, 76, 149, 11, 66, 250, 195, 78, 8, 46, 161, 102, 40, 217, 36, 178, 118, 91, 162, 73, 109, 139, 209, 37, 114, 248, 246, 100, 134, 104, 152, 22, 212, 164, 92, 204, 93, 101, 182, 146, 108, 112, 72, 80, 253, 237, 185, 218, 94, 21, 70, 87, 167, 141, 157, 132, 144, 216, 171, 0, 140, 188, 211, 10, 247, 228, 88, 5, 184, 179, 69, 6, 208, 44, 30, 143, 202, 63, 15, 2, 193, 175, 189, 3, 1, 19, 138, 107, 58, 145, 17, 65, 79, 103, 220, 234, 151, 242, 207, 206, 240, 180, 230, 115, 150, 172, 116, 34, 231, 173, 53, 133, 226, 249, 55, 232, 28, 117, 223, 110, 71, 241, 26, 113, 29, 41, 197, 137, 111, 183, 98, 14, 170, 24, 190, 27, 252, 86, 62, 75, 198, 210, 121, 32, 154, 219, 192, 254, 120, 205, 90, 244, 31, 221, 168, 51, 136, 7, 199, 49, 177, 18, 16, 89, 39, 128, 236, 95, 96, 81, 127, 169, 25, 181, 74, 13, 45, 229, 122, 159, 147, 201, 156, 239, 160, 224, 59, 77, 174, 42, 245, 176, 200, 235, 187, 60, 131, 83, 153, 97, 23, 43, 4, 126, 186, 119, 214, 38, 225, 105, 20, 99, 85, 33, 12, 125],
    # Bogdanov et al., 'PRESENT: An Ultra-Lightweight Block Cipher', CHES 2007
    "PRESENT" => UInt8[12, 5, 6, 11, 9, 0, 10, 13, 3, 14, 15, 8, 4, 7, 1, 2],
    # Banik et al., 'GIFT: A Small Present', CHES 2017
    "GIFT" => UInt8[1, 10, 4, 12, 6, 15, 3, 9, 2, 13, 11, 7, 5, 0, 8, 14],
    # Banik et al., 'Midori: A Block Cipher for Low Energy', ASIACRYPT 2015
    "Midori_Sb0" => UInt8[12, 10, 13, 3, 14, 11, 15, 7, 8, 9, 1, 5, 0, 2, 4, 6],
    # Banik et al., 'Midori: A Block Cipher for Low Energy', ASIACRYPT 2015
    "Midori_Sb1" => UInt8[1, 0, 5, 3, 14, 2, 15, 7, 13, 10, 9, 11, 12, 8, 4, 6],
    # Beierle et al., 'The SKINNY Family of Block Ciphers …', CRYPTO 2016
    "SKINNY_4" => UInt8[12, 6, 9, 0, 1, 10, 2, 11, 3, 8, 5, 13, 4, 14, 7, 15],
    # Shibutani et al., 'Piccolo: An Ultra-Lightweight Blockcipher', CHES 2011
    "Piccolo" => UInt8[14, 4, 11, 2, 3, 8, 0, 9, 1, 10, 7, 15, 6, 12, 5, 13],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S0" => UInt8[3, 8, 15, 1, 10, 6, 5, 11, 14, 13, 4, 2, 7, 0, 9, 12],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S1" => UInt8[15, 12, 2, 7, 9, 0, 5, 10, 1, 11, 14, 8, 6, 13, 3, 4],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S2" => UInt8[8, 6, 7, 9, 3, 12, 10, 15, 13, 1, 14, 4, 0, 11, 5, 2],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S3" => UInt8[0, 15, 11, 8, 12, 9, 6, 3, 13, 1, 2, 4, 10, 7, 5, 14],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S4" => UInt8[1, 15, 8, 3, 12, 0, 11, 6, 2, 5, 4, 10, 9, 14, 7, 13],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S5" => UInt8[15, 5, 2, 11, 4, 10, 9, 12, 0, 3, 14, 8, 13, 6, 7, 1],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S6" => UInt8[7, 2, 12, 5, 8, 4, 6, 11, 14, 9, 1, 15, 13, 3, 10, 0],
    # Anderson, Biham, Knudsen, 'Serpent: A Proposal for the AES', 1998
    "SERPENT_S7" => UInt8[1, 13, 15, 0, 14, 8, 2, 11, 7, 4, 12, 10, 9, 3, 5, 6],
    # Suzaki, Minematsu, Morioka, Kobayashi, 'TWINE: A Lightweight Block Cipher for Multiple Platforms', SAC 2012
    "TWINE" => UInt8[12, 0, 15, 10, 2, 11, 9, 5, 8, 3, 13, 7, 1, 14, 6, 4],
    # Gong, Nikova, Law, 'KLEIN: A New Family of Lightweight Block Ciphers', RFIDSec 2011
    "KLEIN" => UInt8[7, 4, 10, 9, 1, 15, 11, 0, 12, 3, 2, 6, 8, 14, 13, 5],
)
const APN = Dict{String,Vector{UInt8}}(
    # Nyberg, 'Differentially uniform mappings for cryptography', EUROCRYPT 1994 (APN definition); Gold APN family from Gold, IEEE Trans. Inform. Theory, 1968.
    "n4_Gold_x3" => UInt8[0, 1, 8, 15, 12, 10, 1, 1, 10, 15, 15, 12, 8, 10, 8, 12],
    # Gold, 'Maximal Recursive Sequences with 3-Valued Recursive Cross-Correlation Functions', IEEE Trans. Inf. Theory 1968; APN property per Nyberg EUROCRYPT 1994.
    "n5_Gold_x3" => UInt8[0, 1, 8, 15, 10, 31, 23, 4, 26, 25, 3, 6, 9, 30, 5, 20, 14, 18, 22, 12, 24, 16, 21, 27, 2, 28, 11, 19, 13, 7, 17, 29],
    # Gold, IEEE Trans. Inf. Theory 1968; APN property per Nyberg EUROCRYPT 1994.
    "n5_Gold_x5" => UInt8[0, 1, 5, 22, 17, 25, 4, 30, 31, 24, 18, 7, 20, 26, 9, 21, 12, 6, 23, 15, 16, 19, 27, 10, 14, 2, 29, 3, 8, 13, 11, 28],
    # Kasami exponents and APN property per Nyberg EUROCRYPT 1994.
    "n5_Kasami_x15" => UInt8[0, 1, 31, 21, 18, 28, 10, 17, 29, 2, 22, 4, 24, 11, 25, 16, 9, 23, 27, 20, 14, 12, 19, 3, 5, 8, 7, 15, 26, 30, 6, 13],
)
const METADATA = Dict(
    "AES" => Dict{String,Any}("n" => 8, "m" => 8, "is_permutation" => true),
    "AES_inv" => Dict{String,Any}("n" => 8, "m" => 8, "is_permutation" => true),
    "PRESENT" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "GIFT" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "Midori_Sb0" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "Midori_Sb1" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SKINNY_4" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "Piccolo" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S0" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S1" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S2" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S3" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S4" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S5" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S6" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "SERPENT_S7" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "TWINE" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
    "KLEIN" => Dict{String,Any}("n" => 4, "m" => 4, "is_permutation" => true),
)

fixture_names() = sort!(collect(keys(LITERATURE)))
fixture_sbox(name) = SBox(copy(LITERATURE[name]))
fixture_apn(name) = SBox(copy(APN[name]))
fixture_metadata(name) = METADATA[name]
end
