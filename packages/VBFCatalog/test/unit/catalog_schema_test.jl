@testitem "catalog_schema" begin
using VBFCatalog
using VBF
using Test
import SQLite
import DBInterface

@testset "SCHEMA_VERSION exported" begin
    @test SCHEMA_VERSION isa Int
    @test SCHEMA_VERSION ≥ 1
end

@testset "canonical_lut_bytes / lut_sha256_hex" begin
    s = SBox(UInt8[0, 1, 2, 3])
    bytes = canonical_lut_bytes(s)
    # N=2, m=2 → 1 byte per entry, 4 entries
    @test bytes == UInt8[0, 1, 2, 3]

    # n=9 needs 2 bytes per entry (little-endian)
    s9 = SBox(UInt16[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
                     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
                     32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
                     48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
                     64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
                     80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95,
                     96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
                     112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127,
                     128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,
                     144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159,
                     160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,
                     176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191,
                     192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207,
                     208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223,
                     224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,
                     240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255,
                     256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271,
                     272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287,
                     288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303,
                     304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319,
                     320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335,
                     336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351,
                     352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367,
                     368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380, 381, 382, 383,
                     384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399,
                     400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415,
                     416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431,
                     432, 433, 434, 435, 436, 437, 438, 439, 440, 441, 442, 443, 444, 445, 446, 447,
                     448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463,
                     464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479,
                     480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495,
                     496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511])
    b9 = canonical_lut_bytes(s9)
    @test length(b9) == 512 * 2
    # entry 0 → 0x0000 LE → 0x00, 0x00
    @test b9[1:2] == UInt8[0x00, 0x00]
    # entry 256 → 0x0100 LE → 0x00, 0x01
    @test b9[2 * 256 + 1 : 2 * 256 + 2] == UInt8[0x00, 0x01]

    # SHA-256 is deterministic
    @test lut_sha256_hex(s) == lut_sha256_hex(SBox(UInt8[0, 1, 2, 3]))
    # different LUTs hash differently
    @test lut_sha256_hex(s) != lut_sha256_hex(SBox(UInt8[3, 2, 1, 0]))
    # hex format
    @test length(lut_sha256_hex(s)) == 64
    @test all(c -> c in "0123456789abcdef", lut_sha256_hex(s))
end

@testset "create_catalog: schema initialises and is loadable" begin
    mktempdir() do tmp
        path = joinpath(tmp, "test.sqlite")
        db = create_catalog(path; bfa_version = "0.1.0-test", inputs_sha256 = "inputs", implementation_sha256 = "code")

        # SQLite.jl's Row reads via a shared cursor: collect() invalidates the rows because the cursor moves past the last row. Iterate eagerly inside the loop body.
        names = String[]
        for r in DBInterface.execute(
                db, "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
            push!(names, r.name)
        end
        @test "schema_meta" in names
        @test "bibliography" in names
        @test "functions" in names
        @test "source_inputs" in names
        @test "class_members" ∉ names
        @test "equivalence_checks" ∉ names
        @test "reconciliation_disagreements" ∉ names

        # schema_meta populated (first() is cursor-safe; collect() is not).
        meta = first(DBInterface.execute(db, "SELECT * FROM schema_meta LIMIT 1"))
        @test meta.schema_version == SCHEMA_VERSION
        @test meta.bfa_version == "0.1.0-test"
        @test meta.inputs_sha256 == "inputs"
        @test meta.implementation_sha256 == "code"

        close(db)

        # round-trip via load_catalog
        db2 = load_catalog(path)
        meta2 = first(DBInterface.execute(db2, "SELECT * FROM schema_meta LIMIT 1"))
        @test meta2.schema_version == SCHEMA_VERSION
        close(db2)
    end
end

@testset "load_catalog: missing file → ArgumentError" begin
    @test_throws ArgumentError load_catalog("/tmp/definitely-does-not-exist-bfa.sqlite")
end

@testset "load_catalog: schema mismatch is detected" begin
    mktempdir() do tmp
        path = joinpath(tmp, "wrong_schema.sqlite")
        db = SQLite.DB(path)
        DBInterface.execute(db, "CREATE TABLE schema_meta (schema_version INTEGER, built_at TEXT, bfa_version TEXT, git_sha TEXT)")
        DBInterface.execute(db, "INSERT INTO schema_meta VALUES (?, ?, ?, ?)",
                            (999, "now", "fake", "fake"))
        close(db)
        @test_throws ArgumentError load_catalog(path)
    end
end

@testset "is_catalog_built" begin
    @test !is_catalog_built("/tmp/definitely-not-here.sqlite")
    mktempdir() do tmp
        path = joinpath(tmp, "x.sqlite")
        create_catalog(path)
        @test is_catalog_built(path)
    end
end

end
