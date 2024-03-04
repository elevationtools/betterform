
this_script := $(lastword $(MAKEFILE_LIST))
this_dir := $(patsubst %/,%,$(dir $(this_script)))

include $(this_dir)/../terraform_standalone/ctl.mk

CONFIG_JSONNET_FILE ?= config.jsonnet

$(CONFIG_JSON_FILE): $(CONFIG_JSONNET_FILE) \
											$(shell jsonnet-deps $(CONFIG_JSONNET_FILE))
	mkdir -p $(dir $(CONFIG_JSON_FILE))
	jsonnet $(CONFIG_JSONNET_FILE) -o $@

$(this_script):: ;

