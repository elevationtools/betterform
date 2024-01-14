
# Betterform
Infrastructure automation DAG tool.

> WARNING: WORK IN PROGRESS

## Overview

Betterform is a collection of tools to help create automation, particularly for
cloud infrastructure projects such as those that use Terraform.

Key design goals:
- Allow creating multi-stage DAGs, with each stage able to be implemented with
  any language and tooling: Terraform, jsonnet, golang, bash, GNU make,
  CloudFormation, kubectl, etc.
- Provide a general solution for problems in tools like Terraform and jsonnet.
  The solution should be powerful and generic enough to solve problems for many
  tools, rather than requiring a different solution for each tool.


## Common Tooling Problems Addressed

Betterform solves the following deficiencies with common infrastructure
automation tooling.  The solution used (text templating using gomplate) is
generally useful and will likely be able to solve other yet-to-be-discovered
shortcomings of other tools.

### Terraform Problems

The same problems that resulted in products like Terragrunt and Terraspace, most
notably:
- Inability to parameterize `backend` configuration.
- Lack of solution when multi-staging is required. (and Terraform says it's
  required at times).
- Extreme boilerplate when trying to use a module as a library for multiple
  different deployments/environments/etc.

### Jsonnet Problems

- Lack of computed imports.
- Potentially problematic requirement to add configuration for each environment
  variables that needs to be accessed.


## Core Concepts and Terms

#### Wave Program and Wave Interface

A "Wave Program" implements the "Wave Interface" if it does the following:

- Handles commands `up` and `down`
  - i.e. `./prog up` and `./prog down`
  - Note: this is where the name comes from, waves go up and down.

- Respects the following environment variables:
  - `GENFILES`
    - A directory that the wave program MUST use for files that shouldn't be
      checked into version control, but that should still be kept around for use
      by other dependency programs, or because they require a non-negligible
      amount of time to produce.
      - Note: This is what you'd put in your `.gitignore` file.
  - `OUTPUT_DIR`
    - Defines a directory where the wave should store output the is meant to be
      checked into version control.
  - `CONFIG_JSON_FILE`
    - Path to a JSON file that the wave program can read to adapt behavior. The
      wave program MUST document the schema it expects.

Implementation:
- Competely unspecified. It can be implemented however you like.

Notes:
- If a wave program has expectations about the current working directory, then
  it MUST document this.
- The environment variables, if specifying relative paths, must be interpretted
  as relative to the current working directory, not the wave program's
  implementation directory.


#### Orchestrator

A wave program which internally executes a DAG of child "Stages", which are also
wave programs.

Caller Interface:
  - Implements "Standalone Wave" interface, nothing more.

Implementor Interface:
  - Define the stage DAG in Makefile form.
  - Create a directory for each child "Stage".


#### Stage

A single step of an Orchestrator's DAG.  The files contained in the stage are
templates that the Orchestrator will "stamped" with gomplate.  The orchestrator
will then use the stamped files to run the stage.

Caller Interface:
- None, it's not called directly, it's called via the orchestrator.

Implementation Requirements:
- A "stage template directory" must be created directly within the
  orchestrator's implementation directory. The directory name defines the stage
  name.
  - Stage template directory requirements:
    - Contains files that MUST be processable by gomplate (they aren't required
      to use any gomplating, they just need to MUST NOT fail processing by
      gomplate.  Helm charts are currently a problem, this is discussed below).
  - Note: The orchestrator uses this template directory to create the "stage
    stamped directory" in `$GENFILES/$STAGE_NAME`. The directory structure from
    the template directory is maintained.
- Requirements on "stage stamped directory":
  - MUST contain a "ctl" executable that implements the "Wave Interface".

The orchestrator will ensure the following before stamping and running stages:
- Environment variables:
  - `STAGE_NAME` is set to the stage name.
  - `IMPL_DIR` points to the orchestrator's implementation directory (i.e. the
    directory containing the stage template directories).
  - The wave interface environment variables will be resolved to absolute paths.
- The current working directory will not be changed from when the orchestrator
  was executed.
- For a given stage, all dependency stages will have completed successfully
  before it is stamped, so the dependency stage genfiles and outputs are
  available. This means the following things could work:
  - At stamp time:
    ```
    {{ $x := print .Env.OUTPUT_DIR "/earlier_stage/output.json" | data.JSON -}}
    {{ $x.some.json.value }}
    ```
  - At run time:
    ```
    #!/usr/bin/env bash
    cat $OUTPUT_DIR/earlier_stage/output.json
    ```
  (Also similarly with `$GENFILES`)


##### Using a standalone "Wave Program" as a stage.

A standalone wave program can be used as a stage via a few line bash script.  For example:

```shell
#!/usr/bin/env bash
export GENFILES=$GENFILES/this_stage
export OUTPUT_DIR=$OUTPUT_DIR/this_stage
export CONFIG_JSON_FILE=$OUTPUT_DIR/some_prior_stage/stuff.json
exec "{{ .Env.REPO_ROOT }}/foo/bar/my_wave" "$@"
```

Key points:
- You don't have to override the "Wave Interface" env vars, but likely it will
  make sense for the sake of organization and to avoid collisions.
- The standalone wave program can live elsewhere, but the few line script that
  points at it must be implemented as a stage, meaning it lives in the "stage
  template directory".


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
would cause gomplate to fail.  Some possible solutions:
- Use gomplate's `GOMPLATE_LEFT_DELIM/GOMPLATE_RIGHT_DELIM` feature.
- ...or just never use Helm and always use a better tool like jsonnet.

