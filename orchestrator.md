
# Orchestrator Details

## Environment Variables

The orchestrator makes use of the following environment variables to configure
it's behavior.

### Required

- `IMPL_DIR`
  - Path to where the stage template dirs and DAG specification are located.
  - This is different from the current working directory because an orchestrator
    implementation is meant to be written once, then called from many different
    leaf directories, each with a different configurations, in order to support
    different deployments in different locations (dev in us-east, staging in
    eu-north, etc).

### Optional

- `INTERACTIVE`
  - Defaults to `true`.
  - If set to exactly `false` then avoid prompting the user so that it can be
    used in automation.

### Paths with Reasonable Defaults

Generally you shouldn't change these, but also shouldn't assume they equal their
default value when implementing stages.

- `GENFILES`
  - Defaults to `./genfiles`
  - A directory that the wave program MUST use for files that SHOULD NOT be
    checked into version control, but that MUST still be kept around for use
    by other dependency programs, or that SHOULD be kept around to avoid
    unnecessarily repeating time consuming steps.
    - Note: You almost certainly want `.gitignore` to contain `**/genfiles/`.
- `OUTPUT_DIR`
  - Defaults to `.`
  - Defines a directory where the wave MUST store output that is meant to be
    checked into version control.
- `CONFIG_JSON_FILE`
  - Defaults to `./genfiles/config.json`
  - Path to a JSON file that the wave program MAY read to adapt behavior. The
    wave program SHOULD document the schema it expects.
  - Optional for waves that don't need configuration.
- `CONFIG_JSONNET_FILE`
  - Defaults to `./config.jsonnet`
  - A path to a jsonnet file which will produce and/or update
    `CONFIG_JSON_FILE`.
    - GNU make semantics (timestamp) are used to update `CONFIG_JSON_FILE`
      with prerequists as `CONFIG_JSONNET_FILE` and `jsonnet-deps
      $CONFIG_JSONNET_FILE`.
  - Optional for callers of the wave.  If not specified, the caller MUST make
    sure `CONFIG_JSON_FILE` already exists.

> Relative paths in the above environment variables are considered relative to
> the user's current working directory when they call the orchestrator.


## Implementing Stages

### Requirements

- The stage's template directory MUST be directly in the `$IMPL_DIR`.
- Contains an executable named `ctl` which takes the `up` and `down` commands.

Aside from that, there are no requirements.  `ctl` can be a script or a binary.
It can have sibling files, directories, etc.

### Interaction with Orchestrator

#### Step 0) Run Dependencies

First, all dependency stages are run and must be successful before this stage is
stamped.

#### Step 1) Stamping the Stage

The orchestrator stamps the stage's template directory (`$IMPL_DIR/$STAGE_NAME`)
into `$PWD/genfiles/$STAGE_NAME` using `gomplate`.
- In the gomplate templating, `{{ .cfg }}` is a golang map set to the contents
  of `CONFIG_JSON_FILE`.
- `.gomplateignore` may be needed in some cases, for example, Helm charts that
  already contain golang text templating that shouldn't be handled by
  `gomplate`.
- `$PWD` represents the current working directory upon calling the orchestrator.

Since all dependency stages have run to success, the output of dependencies can
be used while stamping.

Example gomplate templating that would use output of a previous stage as well as
config from `CONFIG_JSON_FILE`.
```
Config from CONFIG_JSON_FILE:
{{ .cfg.baz.bop }}

Config from previous stage:
{{ $x = print .Env.OUTPUT_DIR "/dep_stage/some_output.json" | file.Read | json }}
{{ $x.foo.bar }}
```

#### Step 2) Running the Stage

The orchestrator runs the stage's `ctl` with the following:
- The `STAGE_NAME` environment variable set to the name of the stage, which is
  the same as the stage template directory's base name.
- All environment variables mentioned above set, but with paths converted to
  absolute paths.
- The current working directory set to the path of the stage's stamped directory
  (the one under `$PWD/genfiles/$STAGE_NAME`, not the stage's template directory
  under `$IMPL_DIR/$STAGE_NAME`).


## `betterform_dag.mk`

The DAG of stages is defined in `$IMPL_DIR/betterform_dag.mk`.  It is in gnumake
syntax looks something like:
```make
$(call dag_dep, stage_a stage_b, stage_c stage_d)
$(call dag_dep, stage_d, stage_e)
```

- The first line says that `stage_a` and `stage_b` both depend upon `stage_c`
  and `stage_d`.
- The second line says the `stage_d` depends on `stage_e`.
- The third line says `stage_x` depends on `stage_a` and `stage_b`.

This means `stage_e` and `stage_c` could start running in parallel together, and
so on...

It is recommended not to do anything fancy in here except for calling `dag_dep`.
While it is possible to do more, it very while might break things and isn't
officially supported.


## Troubleshooting

### Getting to Raw Vanilla Terraform

When things go wrong it's sometimes handy to be able to use the `terraform` CLI
directly.

The following should work:
```
cd genfiles/some_terraform_stage
terraform init
terraform apply
terraform destroy
# ...etc...
```

Keep in mind that this might not work in general, but will likely work for
Terraform.  This is because the orchestrator sets the environment variables
above, and the stage's `ctl` is expecting these variables to be set.  However,
since Terraform doesn't allow looking at arbitrary environment variables and
none of the above variables are `TF_VAR_...` vars, it should all work out.  The
gomplate stamping will have already resolved any environment variables into
their values.

