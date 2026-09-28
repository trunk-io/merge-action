# merge-action

Hosts the code for the [Trunk Merge](https://docs.trunk.io/merge-graph) GitHub Action, which makes
it easy to upload the required impacted targets for PRs when running your merge queues in
["Parallel" mode](https://docs.trunk.io/merge-graph/configuration#single-parallel-mode). Currently,
this action supports the following build systems:

- [Bazel](https://bazel.build/)

More supported build systems are coming soon! If your build system is not supported by this action
yet, you can still
[upload impacted targets to Trunk Merge](https://docs.trunk.io/merge-graph/impacted-targets)
yourself.

## Overview

Trunk Merge checks and tests all PRs before they merge, guaranteeing that the branches you care
about the most will always pass all tests. Trunk Merge Queues, unlike traditional merge queues, can
run in "Parallel" mode, which increases throughput by dynamically creating merge queues for pull
requests that affect different parts of your codebase instead of testing them all together. That
means no more waiting for your backend changes to test before landing your doc changes!

Running in "Parallel" mode requires providing Trunk Merge with the list of
[impacted targets](https://docs.trunk.io/merge-graph/impacted-targets) resulting from the changes in
your PR. If using a supported build system, this action can take care of getting that list and
sending it to Trunk Merge.

If you do not already have one for your repo, a Trunk Merge Queue can be created at
[app.trunk.io](https://app.trunk.io). Documentation on how to do that can be found
[here](https://docs.trunk.io/merge-graph/set-up-trunk-merge).

### How This Action Works

When run on a pull request, the merge action will compare the merge commit of your PR + the base
branch to the tip of the PR's base branch. With those two commits, we'll query your build system to
get the list of targets that were impacted directly due to the PR's code changes. That list will
then be uploaded to Trunk Merge. This way, when running in "Parallel" mode, Trunk Merge will create
merge queues just for the PRs that share any impacted targets, only testing PRs that actually can
impact one-another against each other.

Marking a PR as impacting every single other PR is also possible using the `impact-all-filters-path`
argument for the action. This is useful for if a PR contains a change that any PRs queued in the
future should also depend on - an example would be PRs that introduce or change workflows run on
every PR.

Sending this list of impacted targets for your PR is required before it can be queued when running
in "Parallel" mode. If you [queue your PR](https://docs.trunk.io/merge-graph/testing-pull-requests)
before the action uploads the list, the PR will wait until the list has been uploaded before being
queued.

## Usage

Running this action in a GitHub workflow will require you knowing your Trunk Repo or Trunk Org API
token.

### Example

An example of how this action would be run in a GitHub workflow is below.

<!-- start usage -->

```yaml
name: Upload Impacted Targets
on: pull_request

jobs:
  compute_impacted_targets:
    name: Compute Impacted Targets
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Compute Impacted Targets
        uses: trunk-io/merge-action@v1
        with:
          # Use your Trunk repo or org API token to authenticate impacted targets uploads.
          # This secret should be provided as a GitHub secret.
          # See https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions.
          trunk-token: ${{ secrets.TRUNK_API_TOKEN }}
```

<!-- end usage -->

For more information on each possible argument you can provide, see
[action.yaml](https://github.com/trunk-io/merge-action/blob/main/action.yaml).

### Without a Trunk secret: `auth: github-actions`

Instead of an API token, the action can log in with the run's own GitHub credential through
[trunk-io/login](https://github.com/trunk-io/login). There is no Trunk secret to store or rotate,
and it works on pull requests from forks, where repository secrets are not available.

To switch, change three things in the workflow:

```yaml
jobs:
  compute_impacted_targets:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read # only needed with impact-all-filters-path on a private repository
      id-token: write # 1. the run's OIDC token
    steps:
      - uses: actions/checkout@v4

      - uses: trunk-io/merge-action@v1
        with:
          auth: github-actions # 2. log in with GitHub instead of a token
          # 3. remove `trunk-token`, then delete the secret once nothing else uses it
```

- **Pull requests from this repository** use the run's OIDC token, which is why the job needs
  `id-token: write`.
- **Pull requests from forks** use the job's `GITHUB_TOKEN`, bound to that pull request and its head
  commit. An organization admin must turn on **Fork PR CI access** for the repository in Trunk
  (Settings → Repositories). GitHub may hold a first-time contributor's run until a maintainer
  approves it.
- Run it on `pull_request`, never `pull_request_target`: the action builds the pull request's code,
  and under `pull_request_target` a fork's code would run with this repository's secrets and a
  write-scoped token.
- The login can only upload impacted targets for this repository. Every other Trunk API refuses it.

`auth` defaults to `trunk-token`, so existing workflows are unchanged until they opt in. The login
runs on Linux (x64, arm64) and Apple silicon macOS runners.

### Tests

To run tests:

```
pnpm install
pnpm test
```

## What is an Impacted Target?

An impacted target is a unit that is affected by a particular PR. For example (using Bazel), a
change at `src/backend/app` will impact the Bazel `src/backend` package. Any two pull requests that
share an impacted target must be tested together; otherwise, they can be tested independently.

## Under the hood

Below is more information about how this action works for specific build systems.

### Bazel

We use Tinder's [bazel-diff](https://github.com/Tinder/bazel-diff) tool to compute the impacted
targets of a particular PR. The tool computes a mapping of package --> hash at the source and dest
shas, then reports any packages which have a differing hash.

## Questions

For any questions, contact us on [Slack](https://slack.trunk.io).
