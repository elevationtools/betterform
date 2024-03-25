
# Version 1

Currently, Betterform is a verison 0 working prototype. This file documents some
of the ideas that should be incorporated into a "version 1".


## Example Usage

> Using "Documentation Driven Design", this is probably what the "Example Usage"
> documentation should be changed to...(it starts the same)...

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

### Operational usage after setup

First, let's start with how the operational usage would look like if Betterform
has already been setup for "My Infra".  The operator wouldn't care much about
the `infra_lib` directory.  Instead, they'd be focused on the `deployments`
directory, which would then look something like this:

> ** BEGIN DIFFERENCES **
> Everything is the same up in the version 0 docs until here.

```
$MY_REPO/deployments/prod
├── eu-north-1
│   ├── cell_config.jsonnet
│   └── my_infra
│       └── betterform.jsonnet
└── us-east-1
    ├── cell_config.jsonnet
    └── my_infra
        └── betterform.jsonnet
```

To bring up and down the "My Infra" project in `eu-north-1`, the user would then:
```
cd $MY_REPO/deployments/prod/eu-north-1/my_infra

betterform help
# Lists what commands are available other than just "up" and "down", if any, and
# any other helpful info.

betterform up
# Now the infra is up.

betterform down
# Now the infra is down again.
```

And that's it! Upon successfully running `betterform up` the directory would look
like the following:
```
$MY_REPO/deployments/prod/eu-north-1/my_infra
├── betterform.jsonnet
├── output/...
└── genfiles/...
```

`output/...` will contain output, if any, usually as one or more JSON files.
These SHOULD be checked into version control.

`genfiles/...` contains other output that SHOULD NOT be checked into version
control (consider putting `**/genfiles` in `.gitignore`).  This generally
contains temporary files, caching, etc.

## Creating this Betterform setup

To make the above work, the user must first create something like the following:
```
$MY_REPO/infra_lib/my_infra (a.k.a IMPL_DIR)
├── betterform.libsonnet
├── stage_one
│   ├── ctl
│   └── some_terraform_code.tf
└── another_stage
    ├── ctl
    ├── some_kube_manifest.yaml
    └── another_kube_manifest.jsonnet
```

`stage_one` and `stage_two` are stage template directories containing the code
which actually brings up infrastructure. It can be Terraform, bash, anything
really.

`$STAGE_NAME/ctl` is an executable file which the orchestrator calls to bring
the stage's infrastructure up or down.
- > See [`/common_stage_utilities.md`](/common_stage_utilities.md) to avoid
  boilerplate for common stage types.

`betterform.libsonnet` would look something like:
```jsonnet
(import 'betterform/orchestrator/impl.libsonnet') {
  implDir: self.baseName(std.thisFile),

  stageDag: {
    stage_one: {},
    another_stage: {
      dependsOn: ['stage_one'],
    },
  },

  help: |||
    This is additional help text that will be displayed for the operator...
  |||,

  // This is the config made available to stages.
  config: {
    // Leaves must override this with the cell's `cell_config.jsonnet`.
    cell: error 'required',

    foo: {
      bar: 'a_default_value',
      baz: error 'a required value that must be specified per cell',
    },
  },
}
```

`$MY_REPO/deployments/prod/eu-north-1/my_infra/betterform.jsonnet` would then
look something like...
```jsonnet
(import 'infra_lib/my_infra/betterform.libsonnet') {
  config: {
    cell: import '../cell_config.jsonnet',
    foo: { baz: 'cheese' },
  },
}
```

> This all assumes that `JSONNET_PATH` is set appropriately.


## genfiles details

The `./genfiles/...` directory looks something like:

```
genfiles
├── betterform_internal
│   └── ...no promises here...
├── stage_one
│   ├── stamp
│   │   ├── ctl
│   │   └── ...etc...
│   ├── status
│   └── logs
│       ├── command-up
│       └── command-down
│
└── another_stage
    └── ...same as stage_one above...
```

Each stage gets its own directory.  The "stamp" directory is where the template
is stamped into and run from.  For Terraform stages, an operator can then
navigate to this directory and run `terraform` CLI commands directly to
troubleshoot, repair, do advanced thing like migrate state, shoot yourself in
the foot, etc.

The `status` file contains either `up`, `down`, or `unknown`.  Missing is
equivalent to `unkno_wn`.

`logs/command-COMMAND_NAME` contains the stdout and stderr (merge together) of
the latest run of the given command.

