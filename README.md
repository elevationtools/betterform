
# Betterform

An infrastructure-as-code tool meant to weave together and fill gaps in other
tools like Terraform, Jsonnet, Helm, etc.


## Key design goals

- Enable creating infrastructure turn-up/turn-down tools expressed as a Directed
  Acyclic Graph (DAG) of one or more "stages".

- Enable stages to be written in any tool, Terraform, bash, golang, etc.  Often
  official documentation for accomplishing a task provides commands calling a
  CLI.

- Enable dependent stages to use the output of dependency stages.

- Enable creating libraries that can be reused in arbitrary different deployment
  settings such as in different clusters and environments (dev, staging, prod,
  etc).

- Enable expressing configuration via Jsonnet.  (Any config language that
  produces JSON can be used, but Jsonnet has native support).

- Enable stages to be templatized so that a common tool can be used to fill the
  missing pieces in tools like Terraform, Helm, Jsonnet, etc (the gaps are
  identified below), rather than requiring specific solutions for each tool.


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
- No convenient access to environment variables. (`-V` + `std.extVar` is tedious
  and can be problematic when jsonnet is invoked for you and you don't have the
  ability to provide `-V` to it).

### Helm Problems

- Lack of ability to parameterize `Values.yaml` with go templating.
- Lack of transitive dependency fetching preventing code reuse through layering.
  (though this arguable isn't solved by Betterform, aside from allowing you to
  avoid Helm as much a possible and focus on better tools like Jsonnet).


## Comparing to Alternatives

### Terragrunt and Terraspace

The most obvious alternatives are Terragrunt and Terraspace. They are motivated
by the same problems in Terraform discussed above.  Compared to these,
Betterform has the following advantages:

- Betterform is not specific to Terraform, instead allowing stages to be written
  in a mix of Terraform, bash calling CLIs, etc.  The Terra\* tools only support
  Terraform stages.

- Betterform requires learning much less single-purpose and framework-specific
  knowledge.  Instead, it makes use of generally useful tools, like `gomplate`
  and Jsonnet.

- The ability to use Jsonnet (or other config language) provides a few benefits:
  - Allows using a more powerful and productive configuration language than pure
    Terraform, allowing writing much more declarative configurations than pure
    Terraform.  Terraform instead just reads the highly declarative
    configuration and converts it into API calls to the cloud to create infra.
  - Allows easily and efficienctly using your configuration outside of Terraform
    when Terraform isn't a good tool for the job. (No need for the slow "init"
    and managing providers and state).

An additional advantage over Terraspace is that it has no dependency on Ruby.

### Tonka

Tonka and Betterform aren't really trying to address the same problem and so
could be reasonably used in complementary roles. Tonka is focused on Jsonnet for
kubernetes application deployments.  Betterform is more intended to bring up the
infrastructure (cloud networking, managed kubernetes service, etc) that the
application deployments would then use.


## Core Concepts

### Orchestrator and Stages

The "orchestrator" is the main way users interact with Betterform.  A user
defines "stages", a DAG relating the stages, and then calls the orchestrator to
run the DAG.

- Each stage is defined as a directory of templates that are "stamped" via
  `gomplate`.  The stamped directory must can an executable named `ctl` which
  takes the `up` and `down` commands (i.e. `./ctl up` and `./ctl down` work).
- The stages have access to JSON based configuration both during stamp time as
  well as at run time.
- Configuration can optionally be given as Jsonnet instead of raw JSON.
- Each stage isn't stamped until all dependency stages have successfully run
  `up`. This means that a dependent stage has access to the output of dependency
  stages both at run time AND at stamp time.
- There is a utility library for common stages types (e.g. Terraform) that take
  care of much of the boilerplate (discussed later).


## Getting Started

- See the [Example Usage with Explanation](./example_usage_explained.md)
- See the [Orchestrator Details](./orchestrator.md) for details on how to work
  with the orchestrator, including how to write stages.
- See [Common Stage Utilities](./common_stage_utilities.md) for utilities meant
  to ease making common types of stages.

> Note: Users should use the executables in`/bin/*` rather than calling directly
> into `/lib/...`


## Project Status

Currently, at the "working prototype" stage.  The implementation makes heavy use
of bash and GNU make.  Long term, different tools should probably be considered
(golang, etc).  Additionally, `gomplate` is currently used for templating but a
different general purpose templating solution could improve upon some
shortcomings of `gomplate` that impact Betterform (discussed below in the "Future
Work" section).


## Future Work

### Core Functionality Integration Tests

Create an integration test of just the core functionality (not the utility
libraries) which doesn't require slow operations like the working demo.

### Working Demo

Create a working demo, similar to the integration test, but focused on teaching
how to use Betterform.  Include use of some common stage utilities, which may be
slow running.

### diffing

Add something like `diff` or `plan` to the "Wave Interface".  For the
orchestrator, it may need to be something like `diff_next`, because you can't
diff something that doesn't have its dependencies up already.

### stamping

Similar to above, perhaps add something like `stamp_next` to stamp at least what
can be stamped.

### support setting `gomplate` delimiters

See https://docs.gomplate.ca/usage/#overriding-the-template-delimiters

### Issues with `gomplate`

Solving the following issues with `gomplate` would be helpful for Betterform

- Calling templates in another file is awkward/boilerplate heavy.
  ```golang
  {{ $_ := file.Read "otherfile.gmp" | tpl }}
  {{ tmpl.Exec "otherfiletmpl" (merge (dict "foo" "bar") .) }}
  ```

- `--input-dir` and `--output-dir` has problematic semantics.  One of these two
  options would solve it:
    - Option 1) Remove files in `--output-dir` that aren't in `--input-dir` to clean up
      previous runs automatically without having to `rm -rf` the whole output dir.
    - Option 2) Make the timestamps of the output files match the timestamps of
      the input files.  This would allow `rm -rf` to work while not confusing
      `make`'s timestamp checking.


## The "Betterform" Name

The "Betterform" name came from first considering the name "Goodform", as in the
expression "good form", but then downgrading from "good" to just "better" to
humbly admit that while it is an improvement to alternatives, it still perhaps
has some work to be truly "good".

Unfortunately, the name "Betterform" may still sound arrogant to some, so
renaming to "Waveform" is being considered, which plays with the "wave" concept
defined below.

