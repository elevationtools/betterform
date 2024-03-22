# See README.md for more information.

# Avoid trying to remake this file
$(lastword $(MAKEFILE_LIST)):: ;

#### Interface ####

# Directory containing the betterform_dag.mk and the stage directories.
IMPL_DIR ?= .
# Directory to place temporary generated files that shouldn't be checked in to
# version control.
GENFILES ?= genfiles
# Directory to place output files that should be checked in to version control.
OUTPUT_DIR ?= .
# Required config files (but which might be generated, which by default it is).
CONFIG_JSON_FILE ?= genfiles/config.json
# Optional conifg file which will generate the CONFIG_JSON_FILE. Set to blank
# and provide CONFIG_JSON_FILE yourself.
CONFIG_JSONNET_FILE ?= config.jsonnet

export JSONNET ?= jsonnet
export JSONNET_DEPS ?= jsonnet-deps

#### Implementation ####

# Lock down the file paths to abs paths.  This is a lot more convenient and safe
# for the stage implementations. (Beware of adding whitespace)
export IMPL_DIR := $(or $(abspath $(IMPL_DIR)), $(error required))
export GENFILES := $(or $(abspath $(GENFILES)), $(error required))
export OUTPUT_DIR := $(or $(abspath $(OUTPUT_DIR)), $(error required))
export CONFIG_JSON_FILE := $(or $(abspath $(CONFIG_JSON_FILE)), $(error required))
# Blank without an error if CONFIG_JSONNET_FILE is blank.
export CONFIG_JSONNET_FILE := $(abspath $(CONFIG_JSONNET_FILE))

DAG_MAKE_FILE := $(IMPL_DIR)/betterform_dag.mk
EVT := $(GENFILES)/events

# Utility function for easing the DAG definition, for use by the included DAG
# file.
#
# Args:
#		1: dependents
#		2: dependencies
STAGES_WITH_DUPS =
define dag_deps_impl
STAGES_WITH_DUPS += $(1) $(2)
$(foreach x, $(1), $(EVT)/$(x)-stamped): $(foreach x, $(2), $(EVT)/$(x)-up)
$(foreach x, $(2), $(EVT)/$(x)-down): $(foreach x, $(1), $(EVT)/$(x)-down)
endef
dag_deps = $(eval $(call dag_deps_impl, $(1), $(2)))

include $(DAG_MAKE_FILE)

STAGES := $(sort $(STAGES_WITH_DUPS))
STAGES_UP := $(foreach x, $(STAGES), $(EVT)/$(x)-up)
STAGES_DOWN := $(foreach x, $(STAGES), $(EVT)/$(x)-down)
STAGES_STAMPED := $(foreach x, $(STAGES), $(EVT)/$(x)-stamped)

up: $(STAGES_UP)
down: $(STAGES_DOWN)
.PHONY: up down

# TODO: This reruns if any impl or output is newer, which is wrong, it should
# only look at direct dependencies.
$(EVT)/%-stamped: $(CONFIG_JSON_FILE) \
		$(shell find $(IMPL_DIR) $(OUTPUT_DIR) -path $(GENFILES) -prune -o -print) \
		| $(EVT) $(OUTPUT_DIR)
	@# TODO: remove files in output-dir that don't exist in input-dir without
	@# removing everything.
	mkdir -p "$(GENFILES)/$*"
	STAGE_NAME="$*" gomplate --context "cfg=$(CONFIG_JSON_FILE)" \
		--input-dir "$(IMPL_DIR)/$*" --output-dir "$(GENFILES)/$*"
	touch $@

ifdef CONFIG_JSONNET_FILE
$(CONFIG_JSON_FILE): $(CONFIG_JSONNET_FILE) \
		$(shell $(JSONNET_DEPS) $(CONFIG_JSONNET_FILE))
	mkdir -p $(dir $(CONFIG_JSON_FILE))
	$(JSONNET) $(CONFIG_JSONNET_FILE) -o $(CONFIG_JSON_FILE)
endif

$(EVT)/%-up: $(EVT)/%-stamped
	rm -f $(EVT)/$*-down
	cd $(GENFILES)/$* && STAGE_NAME="$*" ./ctl up
	touch $@

$(EVT)/%-down:
	rm -f $(EVT)/$*-up
	if test -e $(EVT)/$*-stamped; then \
		(cd $(GENFILES)/$* && STAGE_NAME="$*" ./ctl down && touch $@); \
	else \
		echo "$* skipping, not stamped."; \
	fi

$(GENFILES) $(EVT) $(OUTPUT_DIR):
	mkdir -p $@

.DEFAULT_GOAL := help
.PHONY: help
help:
	@echo "Targets: up down"
	@echo "Internal empty targets for debugging:"
	@echo "  $(EVT)/THE_STAGE_NAME-(up|down|stamped)"

