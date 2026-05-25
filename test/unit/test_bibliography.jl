using BFA
using Test

@testset "parse_bibtex: empty / whitespace input" begin
    @test parse_bibtex("") == BibEntry[]
    @test parse_bibtex("   \n\n  ") == BibEntry[]
end

@testset "parse_bibtex: single minimal entry" begin
    s = """
    @article{Foo2024,
      title = {A Title},
      author = {Alice and Bob},
      year = {2024}
    }
    """
    entries = parse_bibtex(s)
    @test length(entries) == 1
    e = entries[1]
    @test e.bib_key == "Foo2024"
    @test e.entry_type == "article"
    @test e["title"] == "A Title"
    @test e["author"] == "Alice and Bob"
    @test e["year"] == "2024"
end

@testset "parse_bibtex: nested braces inside a value are preserved" begin
    s = """
    @misc{X,
      title = {Some {Nested} {Braces} Inside}
    }
    """
    e = first(parse_bibtex(s))
    @test e["title"] == "Some {Nested} {Braces} Inside"
end

@testset "parse_bibtex: quoted values" begin
    s = """
    @misc{X,
      title = "A quoted title",
      year = "1999"
    }
    """
    e = first(parse_bibtex(s))
    @test e["title"] == "A quoted title"
    @test e["year"] == "1999"
end

@testset "parse_bibtex: comments and stray @ characters" begin
    s = """
    % top-level comment
    @inproceedings{One,
      title = {First}
    }

    % another
    @misc{Two, title = {Second}}
    """
    es = parse_bibtex(s)
    @test length(es) == 2
    @test es[1].bib_key == "One"
    @test es[2].bib_key == "Two"
end

@testset "parse_bibtex: bare numeric value" begin
    s = """
    @article{X,
      year = 2024,
      pages = {1--3}
    }
    """
    e = first(parse_bibtex(s))
    @test e["year"] == "2024"
    @test e["pages"] == "1--3"
end

@testset "parse_bibtex: rejects malformed input" begin
    @test_throws Exception parse_bibtex("@article{X, year}")           # no =
    @test_throws Exception parse_bibtex("@article{X, year = {2024")    # unterminated brace
    @test_throws Exception parse_bibtex("@article{X, year = \"abc")     # unterminated quote
end

@testset "load_bibliography: bundled file parses cleanly" begin
    bib = load_bibliography()
    @test !isempty(bib)
    keys_seen = Set([e.bib_key for e in bib])
    # every entry the catalog cites must be present
    for required in ("FIPS197", "BogdanovEtAl2007", "BanikEtAl2017GIFT",
                     "BanikEtAl2015Midori", "BeierleEtAl2016SKINNY",
                     "ShibutaniEtAl2011Piccolo",
                     "AndersonBihamKnudsen1998Serpent", "Nyberg1994")
        @test required in keys_seen
    end
    # every entry has a year
    for e in bib
        @test haskey(e, "year")
        @test !isempty(e["year"])
    end
end

@testset "BibEntry getindex / get / haskey accept case-insensitive field names" begin
    bib = load_bibliography()
    aes = first(e for e in bib if e.bib_key == "FIPS197")
    @test aes["title"] == aes["TITLE"]
    @test get(aes, "doesnotexist", "default") == "default"
    @test haskey(aes, "year") && !haskey(aes, "nonexistent")
end
