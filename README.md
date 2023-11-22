# merge-action

Hosts the code for the [Trunk Merge](https://docs.trunk.io/merge) GitHub Action, which makes it easy
to upload the required impacted targets for PRs when running your merge queues in
["Parallel" mode](INSERT_LINK_HERE). Currently, this action supports the following build systems:

- [Bazel](https://bazel.build/)

More supported build systems are coming soon! If your build system is not supported by this action
yet, you can still [upload impacted targets to Trunk Merge](INSERT_DOC_LINK) yourself.

## Overview

Trunk Merge checks and tests all PRs before they merge, guaranteeing that the branches you care
about the most will always pass all tests. Trunk Merge Queues, unlike traditional merge queues, can
run in "Parallel" mode, which increases throughput by dynamically creating merge queues for pull
requests that affect different parts of your codebase instead of testing them all together. That
means no more waiting for your backend changes to test before landing your doc changes!

Running in "Parallel" mode requires providing Trunk Merge with the list of
[impacted targets](LINK_HERE) resulting from the changes in your PR. If using a supported build
system, this action can take care of getting that list and sending it to Trunk Merge.

If you do not already have one for your repo, a Trunk Merge Queue can be created at
[app.trunk.io](https://app.trunk.io). Documentation on how to do that can be found
[here](https://docs.trunk.io/merge).

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
in "Parallel" mode. If you [queue your PR](LINK) before the action uploads the list, the PR will
wait until the list has been uploaded before being queued.

## Usage

Running this action in a GitHub workflow will require you knowing your Trunk Repo or Trunk Org API
token. For instructions on how to get that, see [here](LINK).

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
