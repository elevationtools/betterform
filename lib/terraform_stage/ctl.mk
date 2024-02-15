
this_script := $(lastword $(MAKEFILE_LIST))
this_dir := $(patsubst %/,%,$(dir $(this_script)))


#### Interface ####

STAGE_NAME ?= $(error required)
GENFILES ?= $(error required)
OUTPUT_DIR ?= $(error required)
# CURDIR must be the stamped stage directory, which must contain the .tf files.
$(if $(wildcard *.tf), , \
		$(error ERROR: No .tf files found in the working directory: $(CURDIR)))

#### Implementation ####

export STAGE_GENFILES := $(GENFILES)/$(STAGE_NAME)
export STAGE_OUTPUT_DIR := $(OUTPUT_DIR)/$(STAGE_NAME)

.PHONY: up down
up: $(STAGE_GENFILES)/up
down: $(STAGE_GENFILES)/down

$(STAGE_GENFILES)/up: $(STAGE_OUTPUT_DIR)/.terraform.lock.hcl
	rm -f $(STAGE_GENFILES)/down
	$(this_dir)/internal_helper apply_and_output
	touch $@

$(STAGE_OUTPUT_DIR)/.terraform.lock.hcl: $(STAGE_GENFILES)/dirs_created \
		$(shell find $(STAGE_GENFILES) -path $(STAGE_GENFILES)/up -prune -o \
																		-path $(STAGE_GENFILES)/down -prune -o \
																		-type f -print)
	$(this_dir)/internal_helper init
	touch $@

$(STAGE_GENFILES)/down: $(STAGE_OUTPUT_DIR)/.terraform.lock.hcl
	rm -f $(STAGE_GENFILES)/up
	$(this_dir)/internal_helper destroy
	touch $@

$(STAGE_OUTPUT_DIR)/dirs_created:
	mkdir -p $(STAGE_GENFILES)
	mkdir -p $(STAGE_OUTPUT_DIR)
	touch $@

$(this_script):: ; # Don't try to remake this file.

