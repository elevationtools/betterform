
# Betterform

An infrastructure-as-code tool meant to fill gaps in other tools like Terraform,
Jsonnet, etc.


## Key design goals

- Provide a general templating solution to fill missing pieces in tools like
  Terraform and Jsonnet.  The solution should be powerful and generic enough to
  solve problems for many tools, rather than requiring a different solution for
  each tool.

- Allow creating a DAG of "stages", with each stage able to be implemented with
  any language and tooling such as Terraform, jsonnet, golang, bash, GNU make,
  CloudFormation, kubectl, etc.


## Comparing to Alternatives

The most obvious alternatives are Terragrunt and Terraspace. They are motivated
by the same problems in Terraform (discussed below) that motivated this project.
Betterform has the following advantages:

- It's not specific to Terraform.  It's often more productive to mix Terraform
  with other tooling, for example, direct use of `kubectl` combined with
  `jsonnet`.  Betterform supports this more general purpose use case and is
  useful in solving similar problems in any tooling, even tools that don't yet
  exist!

- Betterform requires learning much less single-purpose and framework-specific
  knowledge.  Instead, it makes use of generally useful tools, like `gomplate`.


## Status

Currently, at the "working prototype" stage.  The implementation makes heavy use
of bash and GNU make.  Long term, different tools should probably be considered
(golang, etc).  Additionally, `gomplate` is currently used for templating but a
different general purpose templating solution could improve upon some
shortcomings of `gomplate` that impact Betterform.


## Common Tooling Problems Addressed

This section describes some of the problems with common tools that motivated
Betterform.

### Terraform Problems

- Inability to parameterize `backend` configuration.
- Lack of solution when multi-staging is required. (and [Terraform admits it's
  required in many common
  cases](https://github.com/hashicorp/terraform/issues/27785#issuecomment-780017326)).
- Extreme boilerplate when trying to use a module as a library for multiple
  different deployments/environments/etc.  In particular, there is much
  redundancy of the `terraform` and `provider` blocks.

These are the same problems that motivated the existence of products like
Terragrunt and Terraspace.

### Jsonnet Problems

- Lack of computed imports.
- Potentially problematic requirement to add configuration for each environment
  variables that needs to be accessed.

### Helm Problems

- Lack of ability to parameterize `Values.yaml`.
- Lack of transitive dependency fetching preventing code reuse through layering.
  (this is only indirectly solved by Betterform).

> NOTE: Support for including Helm chart sources will require an additional
> feature to allow passing to `gomplate` different values for `--left-delim` and
> `--right-delim`.  Helm charts can still be used today if they are referenced
> by name rather than directly including the source.


## Core Concepts

### Wave Program and Wave Interface

The core concept of Betterform is a "Wave Program".  A program is a "Wave
Program" (or just "wave" for short) if it implements the "Wave Interface", which
is canonically defined here by the following requirements:

- Is executable.

- MUST implement `up` and/or `down` commands.
  - Note: This is where the name comes from, waves go up and down.

- MUST handle the command `help`, which MUST be the default command.
  - i.e. running both `./prog help` and `./prog` will show help.
  - `help` SHOULD print the list of all commands available and any other
    important information to know how to use the wave.
  - If only `up` and `down` are available, then help can optionally be blank.

- Respects the following environment variables:
  - `GENFILES`
    - Defaults to `./genfiles`
    - A directory that the wave program MUST use for files that SHOULD NOT be
      checked into version control, but that MUST still be kept around for use
      by other dependency programs, or that SHOULD be kept around to avoid
      unnecessarily repeating time consuming steps.
      - Note: You almost certainly want `.gitignore` to contain `**/genfiles/`.
  - `OUTPUT_DIR`
    - Defaults to `.`
    - Defines a directory where the wave should store output that is meant to be
      checked into version control.
  - `CONFIG_JSON_FILE`
    - Defaults to `./genfiles/config.json`
    - Path to a JSON file that the wave program can read to adapt behavior. The
      wave program SHOULD document the schema it expects.
    - Optional for waves that don't need configuration.
  - `CONFIG_JSONNET_FILE`
    - Defaults to `./config.jsonnet`
    - A path to a jsonnet file which will produce and/or update
      `CONFIG_JSON_FILE`.
      - Default GNU make semantics are used to update `CONFIG_JSON_FILE` with
        prerequists as `CONFIG_JSONNET_FILE` and
        `jsonnet-deps $CONFIG_JSONNET_FILE`.
    - Optional for wave implementations (and so far none of the standard waves
      in the library use this).
    - Optional for callers of the wave.  If not specified, the caller MUST make
      sure `CONFIG_JSON_FILE` already exists.
  - `INTERACTIVE`
    - Defaults to unset.
    - If set to exactly `false` then avoid prompting the user so that it can be
      used in automation.
  - `IMPL_DIR`
    - Defaults to `.`
    - Path to where the wave program's implementation files are located.  This
      is often different from the current working directory because wave's are
      meant to be implemented once, then called from many different directories,
      each with a different configurations, in order to support different
      deployments in different locations (dev in us-east, staging in eu-north,
      etc).

Notes:
- If a wave program has expectations about the current working directory or
  `IMPL_DIR`, then it MUST document this.
- Relative paths in the above environment variables are considered relative to
  the current working directory when the wave program is called.

Implementation Requirements:
- Competely unspecified. It can be implemented however you like in any language.


## Standard Library

The following waves are implemented under `./lib/`.  They should be used via the
symlinks `./bin/betterform_*`.

### Standalone Waves

#### `terraform_standalone`

A wave program which stamps `$IMPL_DIR/template` using `gomplate` to
`$GENFILES/stamped` and then runs terraform within that directory.

This cannot be used as an orchestrator stage.  Instead use
`./lib/orchestrator/stage/terraform`.

#### `terraform_jsonnet_standalone`

The same as `terraform_standalone` except that `CONFIG_JSONNET_FILE` is used
instead of `CONFIG_JSON_FILE`.

> TODO: deprecate this and implement the functionality within
> `terraform_standalone` directly.

#### `terraform_state_storage_aws`

A wave program which creates the AWS S3 and DynamoDB resources to be used for
terraform state storage.

### Orchestrator and Stages

The orchestrator is a wave program which internally executes a DAG of child
"stages", each of which it stamps with `gomplate`, and upon stamping becomes a
wave program itself.

[`./lib/orchestrator/`](./lib/orchestrator/).  See the README for details.

Most standalone waves in the standard library cannot be used directly as stages,
so instead they have implementations in `./lib/orchestrator/stage/*`.


## Future Work

### diffing

Add something like `diff` or `plan` to the "Wave Interface".  For the
orchestrator, it may need to be something like `diff_next`, because you can't
diff something that doesn't have its dependencies up already.

### stamping

Similar to above, perhaps add something like `stamp_next` to stamp at least what
can be stamped.

### Helm support

Helm also uses go templating and therefore a Helm chart in a stage template
would cause gomplate to fail. Also see the related "future work" item in
[`./lib/orchestrator/README.md`](./lib/orchestrator/README.md).


## The "Betterform" Name

The "Betterform" name came from first considering the name "Goodform", as in the
expression "good form", but then downgrading from "good" to just "better" to
humbly admit that while it is an improvement to alternatives, it still perhaps
has some work to be truly "good".

Unfortunately, the name "Betterform" may still sound arrogant to some, so
renaming to "Waveform" is being considered, which plays with the "wave" concept
defined below.

