# Implements fast tests for Sections 3.1–3.2 and Conjecture 1.
# Paper: Baudrin, Galissant and Perrin (2025), "Exploring the Set of APN Functions", BFA 2025
# Section: 3 — Towards a Practical Classification of all Known APN Functions
#
# Pseudocode:
#   1. Run bounded checks and independent certificate validation.
# VBF API used: ea_class_orbits, ccz_equivalent_function
using Test
using VBF

include("certificate_oracle.jl")
include("audit_saved_evidence.jl")
include("test_section31.jl")
include("test_section32.jl")
include("test_conjecture1.jl")
include("test_evidence.jl")
include("test_section32_census_drivers.jl")
