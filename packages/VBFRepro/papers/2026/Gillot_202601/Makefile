include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk
JULIA_FLAGS ?=
limit ?= 5
max_evaluations ?= 10000
max_nodes ?= 1000000
sample_size ?= 5
save_results ?= false
seed ?= 940
full_search ?= false
timeout_seconds ?= 60
input_path ?=
switching_path ?=
boolean_path ?= $(MAKEFILE_DIR)/input/author_data/class-2-6.txt
max_solutions ?= 20
max_subfunctions ?= 10

.DEFAULT_GOAL := help
.PHONY: help test report clean_results all_tables fetch_inputs table1 table2 table3 table4 table5 table6 table7 table8 table9 section3 section6 section8 lemma1 lemma2 lemma3 lemma4 proposition1

test:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) "$(MAKEFILE_DIR)/test/runtests.jl"
report:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) "$(MAKEFILE_DIR)/report.jl"
clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"
all_tables: table1 table2 table3 table4 table5 table6 table7 table8 table9

lemma1:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/lemma1.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); functions=known===nothing ? [gold_apn(4)] : known.representatives; gl_report("lemma1",gl_lemma1(functions;limit=$(full_search) ? length(functions) : min($(limit),length(functions)),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

lemma2:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/lemma2.jl"); gl_report("lemma2",gl_lemma2(max_nodes=$(max_nodes),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

lemma3:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/lemma3.jl"); gl_report("lemma3",gl_lemma3(max_nodes=$(max_nodes),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

lemma4:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/lemma4.jl"); gl_report("lemma4",gl_lemma4(max_nodes=$(max_nodes),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

proposition1:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/proposition1.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); functions=known===nothing ? [gold_apn(4)] : known.representatives; gl_report("proposition1",gl_proposition1(functions;limit=$(full_search) ? length(functions) : min($(limit),length(functions)),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

section3:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/section3.jl"); gl_report("section3",gl_section3(save_results=$(save_results)))'

section6:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/section6.jl"); gl_report("section6",gl_section6(checkpoint_path="$(switching_path)",census_path="$(input_path)",limit=$(full_search) ? 716 : $(limit),max_evaluations=$(max_evaluations),fresh_samples=$(sample_size),max_nodes=$(max_nodes),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

section8:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/section8.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); roots=known===nothing ? Pair{String,SBox}[] : sort!(collect(known.roots);by=first); gl_report("section8",gl_section8(path="$(boolean_path)",max_evaluations=$(max_evaluations),max_candidates=$(max_subfunctions),known_roots=roots,max_nodes=$(max_nodes),max_solutions=$(max_solutions),seed=$(seed),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table1:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table1.jl"); gl_report("table1",gl_table1(path="$(boolean_path)",limit=$(full_search) ? 150356 : $(limit),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table2:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table2.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); gl_report("table2",gl_table2(known=known,limit=$(full_search) ? 14 : $(limit),max_nodes=$(max_nodes),compute_gamma=true,timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table3:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table3.jl"); gl_report("table3",gl_table3(limit=$(full_search) ? 14 : $(limit),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table4:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table4.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); functions=known===nothing ? [gold_apn(4)] : known.representatives; gl_report("table4",gl_table4(functions;limit=$(full_search) ? length(functions) : min($(limit),length(functions)),timeout_seconds=$(timeout_seconds),save_results=$(save_results),max_comparisons=$(max_evaluations),max_nodes=$(max_nodes),seed=$(seed)))'

table5:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table5.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); functions=known===nothing ? [gold_apn(4)] : known.representatives; gl_report("table5",gl_table5(functions;limit=$(full_search) ? length(functions) : min($(limit),length(functions)),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table6:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table6.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); roots=known===nothing ? Pair{String,SBox}[] : sort!(collect(known.roots);by=first); functions=known===nothing ? [gold_apn(4)] : known.representatives; gl_report("table6",gl_table6(functions;limit=$(full_search) ? length(functions) : min($(limit),length(functions)),max_subfunctions=$(max_subfunctions),max_comparisons=$(max_evaluations),known_roots=roots,max_nodes=$(max_nodes),max_solutions=$(max_solutions),seed=$(seed),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table7:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table7.jl"); gl_report("table7",gl_table7(path="$(boolean_path)",limit=$(full_search) ? 150356 : $(limit),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

table8:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table8.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); functions=known===nothing ? [gold_apn(4)] : known.representatives; gl_report("table8",gl_table8(functions;limit=$(full_search) ? length(functions) : min($(limit),length(functions)),timeout_seconds=$(timeout_seconds),save_results=$(save_results),max_nodes=$(max_nodes)))'

table9:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/table9.jl"); known=isempty("$(input_path)") ? nothing : gl_load_known_representatives("$(input_path)"); roots=known===nothing ? Pair{String,SBox}[] : sort!(collect(known.roots);by=first); gl_report("table9",gl_table9(limit=$(full_search) ? 13 : $(limit),max_comparisons=$(max_evaluations),known_roots=roots,max_nodes=$(max_nodes),max_solutions=$(max_solutions),seed=$(seed),timeout_seconds=$(timeout_seconds),save_results=$(save_results)))'

fetch_inputs:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/fetch_inputs.jl"); gl_fetch_inputs()'

help:
	@echo "Gillot and Langevin (2026), Observation of known APNs"
	@echo "Targets: test report fetch_inputs all_tables table1..table9 section3 section6 section8 lemma1..lemma4 proposition1 clean_results"
	@echo "Params: limit max_evaluations max_nodes sample_size max_solutions max_subfunctions timeout_seconds save_results seed full_search input_path switching_path boolean_path JULIA_FLAGS"

.PHONY: section2
section2:
	$(JULIA) $(JULIA_FLAGS) $(JULIA_PROJECT) "$(MAKEFILE_DIR)/section2.jl"
