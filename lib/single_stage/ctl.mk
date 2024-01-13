
this_script := $(lastword $(MAKEFILE_LIST))
this_dir := $(patsubst %/,%,$(dir $(this_script)))


#### Interface ####

export GENFILES ?= genfiles
export CONFIG_JSON_FILE ?= $(GENFILES)/config.json
export OUTPUT_FILE ?= output.json

.PHONY: help stamp init up down clean
help:
	@cat $(this_dir)/help.txt
stamp: $(GENFILES)/stamped
init: .terraform.lock.hcl
up: $(GENFILES)/up
down: $(GENFILES)/down


#### Implementation ####

$(GENFILES)/up: .terraform.lock.hcl
	rm -f $(GENFILES)/down
	$(this_dir)/internal_helper up
	touch $@

.terraform.lock.hcl: $(GENFILES)/stamped
	$(this_dir)/internal_helper init

$(GENFILES)/stamped: $(GENFILES) $(CONFIG_JSON_FILE) \
		$(shell find . -path "$(GENFILES)" -prune -o -type f -print)
	gomplate --input-dir template --output-dir "$(GENFILES)/stamp" \
		--context "cfg=$(CONFIG_JSON_FILE)"

$(GENFILES)/down: .terraform.lock.hcl
	rm -f $(GENFILES)/up
	cd $(GENFILES)/stamp && terraform destroy

$(GENFILES):
	mkdir -p $@

clean:
	rm -rf $(GENFILES)

$(this_script):: ; # Don't try to remake this file.

