
# Example Usage with Explanation

Imagine a user needs to bring up infrastructure in a project cleverly called "My
Infra".  They need to bring this up in 2 separate regions, `eu-north-1` and
`us-east-1` in production.

Assume the user has a repo that looks like the following:
```
$MY_REPO
├── deployments
│   └── prod
│       ├── eu-north-1
│       │      └── my_infra
│       └── us-east-1
│              └── my_infra
└── infra_lib
    └── my_infra
 
``` 

- `infra_lib` contains libraries of infrastructure-as-code that can be called
  with a specific configuration to bring up infrastructure.
- `deployments` contains directories for each tangible instantiation of
  infrastructure.  (e.g. `prod` deployed to `eu-north-1`).  Each of these leaf
  directories calls into `infra_lib` and passes it the specific configuration
  needed.

## Operational usage after setup

First, let's start with how the operational usage would look like if Betterform
has already been setup for "My Infra".  The operator wouldn't care much about
the `infra_lib` directory.  Instead, they'd be focused on the `deployments`
directory, which would then look something like this:

```
$MY_REPO/deployments/prod
├── eu-north-1
│   ├── cell_config.jsonnet
│   └── my_infra
│       ├── config.jsonnet
│       └── ctl
└── us-east-1
    ├── cell_config.jsonnet
    └── my_infra
        ├── config.jsonnet
        └── ctl
```

To bring up and down the "My Infra" project in `eu-north-1`, the user would then:
```
cd $MY_REPO/deployments/prod/eu-north-1/my_infra
./ctl help
# Learn what commands are available other than just "up" and "down", if any.
./ctl up
# Now the infra is up.
./ctl down
# Now the infra is down again.
```

And that's it! Upon successfully running `./ctl up` the directory would look
like the following:
```
$MY_REPO/deployments/prod/eu-north-1/my_infra
├── config.jsonnet
├── ctl
├── ...output_files_and_dirs...
└── genfiles/...
```

`...output_files_and_dirs...` will contain output, if any, usually as one or
more JSON files possibly nested under directories.  These SHOULD be checked into
version control.  By convention, stages SHOULD output to
`./$STAGE_NAME/output.json` or similar, but this isn't enforced.

`genfiles/...` contains other output that SHOULD NOT be checked into version
control.  This generally contains temporary files, caching, etc.

The leaf `ctl` file is an executable that looks like the following: 
```
#!/usr/bin/env bash
cd "$(dirname "$(readlink -f "$0")")"
exec "$MY_REPO/infra_lib/my_infra" "$@"
```

> The output files and `genfiles` directories are created in the caller's
> current working directory, which is why the `cd` is done in `ctl` above.  It
> allows calling `ctl` from anywhere and it will properly set the current
> working directory.  The `cd` line could be omitted if users are forced to
> always run `./ctl` from its own directory.

The jsonnet config files are discussed later.

## Creating this Betterform setup

To make the above work, the user must first create something like the following:
```
$MY_REPO/infra_lib/my_infra (a.k.a IMPL_DIR)
├── ctl
├── config.libsonnet
├── betterform_dag.mk
├── stage_one
│   ├── ctl
│   └── some_terraform_code.tf
└── another_stage
    ├── ctl
    └── some_kube_manifest.yaml
```

`ctl` would look something like:
```bash
#!/usr/bin/env bash
export IMPL_DIR="$(dirname "$(readlink -f "$0")")"
exec betterform_orchestrator "$@"
```


It could also optionally provide additional documentation if the operator enters
the `help` command.  `betterform_orchestrator` requires `IMPL_DIR` to be set.

`betterform_dag.mk` defines the DAG relating the stages and would look something
like:
```make
$(call dag_deps stage_one, )
$(call dag_deps another_stage, stage_one)
```
This means  `stage_one` has no dependencies. `another_stage` depends on
`stage_one`.

`stage_one` and `stage_two` are stage template directories containing the code
which actually brings up infrastructure. It can be Terraform, bash, anything
really.

`$STAGE_NAME/ctl` are executable files which the orchestrator calls to bring the
stage's infrastructure up or down.
- > See [`/common_stage_utilities.md`](/common_stage_utilities.md) to avoid
  boilerplate for common stage types.


## jsonnet config files

Assume we're here
```
cd prod/eu-north-1/my_infra
```

Running `./ctl` will cause the orchestrator to effectively run `jsonnet
./config.jsonnet` and store the output to `genfiles/config.json`.  Then, all
stages' implementation code will have access to the config via this JSON file.
When the orchestrator stamps stage templates with gomplate, the config file is
also available as `{{ .cfg }}` as a golang map.

The other jsonnet files `cell_config.jsonnet` and `$IMPL_DIR/config.libsonnet`
are listed here because very likely the leaf `config.jsonnet` file would import
both those other Jsonnet files.  The leaf could look something like:
```
(import 'infra_lib/my_infra/config.libsonnet')(
  cell_config=import '../cell_config.jsonnet'
)
```
(Note this requires that `$MY_REPO` is on the `JSONNET_PATH`)

