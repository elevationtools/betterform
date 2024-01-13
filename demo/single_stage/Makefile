
include $(REPO_ROOT)/lib/single_stage/ctl.mk

genfiles/config.json: config.jsonnet
	jsonnet -V PWD config.jsonnet -o $@

