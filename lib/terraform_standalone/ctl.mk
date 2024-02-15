
this_script := $(lastword $(MAKEFILE_LIST))
this_dir := $(patsubst %/,%,$(dir $(this_script)))


#### Interface ####

IMPL_DIR ?= .
GENFILES ?= genfiles
CONFIG_JSON_FILE ?= $(GENFILES)/config.json
OUTPUT_FILE ?= output.json

# Convert main environment variable paths to abs paths.
export IMPL_DIR := $(abspath $(IMPL_DIR))
export GENFILES := $(abspath $(GENFILES))
export CONFIG_JSON_FILE := $(abspath $(CONFIG_JSON_FILE))
export OUTPUT_FILE := $(abspath $(OUTPUT_FILE))

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
	touch $@

$(GENFILES)/stamped: $(GENFILES)/dirs_created $(CONFIG_JSON_FILE) \
		$(shell find $(IMPL_DIR)/template -type f)
	gomplate --input-dir $(IMPL_DIR)/template --output-dir "$(GENFILES)/stamp" \
		--context "cfg=$(CONFIG_JSON_FILE)"
	touch $@

$(GENFILES)/down: .terraform.lock.hcl $(GENFILES)/stamped
	rm -f $(GENFILES)/up
	$(this_dir)/internal_helper down
	touch $@

$(GENFILES)/dirs_created:
	mkdir -p $(GENFILES)
	touch $@

clean:
	rm -rf $(GENFILES)

$(this_script):: ; # Don't try to remake this file.

