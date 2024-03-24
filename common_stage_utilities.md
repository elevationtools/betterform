
# Common Stage Utilities

## Usage

To use anything from the utility library, just point your stage's `ctl` at the
given executable.  For example:

`my_orchestrator_impl_dir/my_stage/ctl`
```
#!/usr/bin/env bash
exec betterform_stage_terraform "$@"
```


## Utility Library

Currently there are 2 common stage types implemented.

### Terraform

Location: `/bin/betterform_stage_terraform`

### Terraform State Storage on AWS

Location: `/bin/betterform_stage_terraform_state_storage_aws`

