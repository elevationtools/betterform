
this_script := $(lastword $(MAKEFILE_LIST))
this_dir := $(patsubst %/,%,$(dir $(this_script)))


#### Interface ####

export GENFILES ?= genfiles
export CONFIG_JSON_FILE ?= genfiles/config.json
export OUTPUT_FILE ?= output.json

.PHONY: help stamp init up down clean
help:
	@cat $(this_dir)/help.txt
stamp: $(GENFILES)/stamped
init: .terraform.lock.hcl
up: $(GENFILES)/up
down: $(GENFILES)/down


#### Implementation ####

$(GENFILES)/up: .terraform.lock.hcl $(GENFILES)/stamped
	rm -f $(GENFILES)/down
	$(this_dir)/internal_helper up
	touch $@

.terraform.lock.hcl: $(GENFILES)/stamped
	$(this_dir)/internal_helper init

$(GENFILES)/stamped: $(GENFILES) $(CONFIG_JSON_FILE) \
		$(shell find template -type f)
	gomplate --input-dir template --output-dir "$(GENFILES)/stamp" \
		--context "cfg=$(CONFIG_JSON_FILE)"

$(GENFILES)/down: .terraform.lock.hcl $(GENFILES)/stamped
	rm -f $(GENFILES)/up
	$(this_dir)/internal_helper down
	touch $@

$(GENFILES):
	mkdir -p $@

clean:
	rm -rf $(GENFILES)

$(this_script):: ; # Don't try to remake this file.

