# See README.md for more information.
#
# Requirements:
# - CURDIR should be the $cell_dir, or under it.
# - CONFIG_JSON must be a json file resulting from a derivative of
#   ./config.libsonnet

# The directory containing this file. (this line must come before any includes)
this_script := $(lastword $(MAKEFILE_LIST))
this_dir := $(dir $(this_script))


# Lock down the file paths to abs paths.  This is a lot more convenient and safe
# for the stage implementations.
export IMPL_DIR := $(or $(abspath $(IMPL_DIR)), $(error required))
export GENFILES := $(or $(abspath $(GENFILES)), $(error required))
export CONFIG_JSON_FILE := $(or $(abspath $(CONFIG_JSON_FILE)), $(error required))
export OUTPUT_DIR := $(or $(abspath $(OUTPUT_DIR)), $(error required))

DAG_MAKE_FILE ?= $(abspath $(IMPL_DIR)/dag.mk)

# Utility function for easing the DAG definition, for use by the included DAG
# file.
#
# Args:
#		1: dependents
#		2: dependencies
define define_stage_impl
STAGES += $(1)
$(foreach x, $(1), $(x)-up): $(foreach x, $(2), $(x)-up)
$(foreach x, $(2), $(x)-down): $(foreach x, $(1), $(x)-down)
endef
define_stage = $(eval $(call define_stage_impl, $(1), $(2)))

include $(DAG_MAKE_FILE)

STAGES_UP := $(foreach x, $(STAGES), $(x)-up)
STAGES_DOWN := $(foreach x, $(STAGES), $(x)-down)
STAGES_STAMPED := $(foreach x, $(STAGES), $(x)-stamped)

up: $(STAGES_UP)
down: $(STAGES_DOWN)

$(STAGES_STAMPED): %-stamped: $(GENFILES) $(OUTPUT_DIR) \
		$(shell find $(IMPL_DIR) -type f) $(CONFIG_JSON_FILE)
	@# TODO: remove files in output-dir that don't exist in input-dir without
	@# removing everything.
	STAGE_NAME="$*" gomplate --context "cfg=$(CONFIG_JSON_FILE)" \
		--input-dir "$(IMPL_DIR)/$*" --output-dir "$(GENFILES)/$*"

$(STAGES_UP): %-up: %-stamped
	STAGE_NAME="$*" $(GENFILES)/$*/ctl up

$(STAGES_DOWN): %-down: %-stamped
	STAGE_NAME="$*" $(GENFILES)/$*/ctl down

$(OUTPUT_DIR) $(GENFILES):
	mkdir -p $@

.DEFAULT_GOAL := help
.PHONY: help
help:
	@echo ERROR: no goal specified
	exit 1

$(this_script):: ;

