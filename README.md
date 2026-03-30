<!-- generate TOC using `go run sigs.k8s.io/mdtoc@df98f15148e5fe76b247c6ec5585a2100f2b4e09 --inplace README.md` -->
<!-- toc -->
- [Actions](#actions)
  - [Workflows](#workflows)
  - [Usage examples](#usage-examples)
  - [GitHub Actions security and policies](#github-actions-security-and-policies)
  - [Dependabot and Actions workflow imports](#dependabot-and-actions-workflow-imports)
  - [Versioning for container images](#versioning-for-container-images)
  - [Go Versioning in workflows](#go-versioning-in-workflows)
<!-- /toc -->

# Actions

> reusable GitHub actions across several projects

This repo is for reusable workflows to run in GitHub Actions for the GeoNet program.
The workflows are not publicly supported and come with absolutely no warranty.

## Workflows

There are three types of workflows in this repo

- reusable: GeoNet downstream implementations of existing actions or common patterns
- reusable _apps_: combined function workflows which include several other reusable workflows
- GeoNet/Actions maintainability: workflows which support the consistency of the workflows in this repo

The workflows are intended to work with and around the maintainers of GeoNet software for automations which are valuable to the project.

## Usage examples

Refer to [USAGE.md](USAGE.md)

## GitHub Actions security and policies

To ensure security of the GeoNet platform we must follow secure practices for GitHub Actions.

GeoNet follows the secure practices documented by GitHub <https://docs.github.com/en/actions/reference/security/secure-use>

- Limit Actions to Verified Actions and an Allowlist

GitHub Actions are limited by organisation policy to those marked Verified on GitHub Marketplace.

Other third-party Actions require review to be allowed or forked.

- All external and third-party GitHub Actions MUST be pinned to an immutable full-length commit SHA

GitHub Actions can be limited by organisation policy to only allow references pinned to a full-length commit SHA.

![Require actions to be pinned to a full-length commit SHA](full-length-commit-sha.png)

A number of supply chain attacks have relied on the version tags values being overwritten with malicious code.

Use the full-length commit SHA.

```yaml
# UNSAFE: tag can be moved
- uses: actions/checkout@v4
- uses: some-org/some-action@main   # branch refs are worst of all

# SAFE: pinned to immutable SHA
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
- uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af  # v4.1.0
```

- Principle of least privilege for access to GITHUB_TOKEN and GitHub Secrets values

Limit workflows that use GitHub Secrets values due to the risk of secrets exposure.

Where required define explicit sets of permissions required for a workflow to run.

```
permissions: read-all   # deny all write at workflow level

jobs:
  test:
    permissions:
      contents: read   # only needs to read code

  publish-results:
    permissions:
      checks: write         # needs to write check results
      pull-requests: write  # needs to comment on PR
      contents: read

  release:
    permissions:
      contents: write   # only this job needs to push tags/releases
      packages: write  # and publish packages
```

- Avoid running any GitHub Actions from forks of repositories

GitHub repository forks create security exposure for any GitHub Secrets values.
Repository forks should not run GitHub Actions jobs without an approval step.

- Avoid fields that can be used for script injection attacks <https://docs.github.com/en/actions/concepts/security/script-injections>

- Review good practices to mitigate script attacks <https://docs.github.com/en/actions/reference/security/secure-use#good-practices-for-mitigating-script-injection-attacks>

## Dependabot and Actions workflow imports

Dependabot is enabled for this repo, see the config in [.github/dependabot.yml](./.github/dependabot.yml).
It will automatically update create PRs to update the Actions workflow imports once a week in a seemingly staggered way.

To force an update of every external import, run `hack/update-actions-imports.sh` and commit the changes in a new PR.

## Versioning for container images

Container registries utilise content addressed storage, meaning to get some data (blob, image), you must request what it's digest is (the process behind tags).
When pushing images using the reusable Docker or Ko builds, the images will always be tagged as latest or their digest.
In order to precisely tag a container image, use the image promotion action.

The digests for images are able to be found with:

```shell
crane digest IMAGE_REF
```

or in the logs of the workflow run.

## Go Versioning in workflows

The default version used in the Go workflows is set to the preceding stable release ("oldstable"). This version will also
be supplied as the build argument `CI_GO_IMAGE` for the resuable docker build workflow, allowing users to the ability to
keep their containers in sync with the latest minor/patch release:

```dockerfile
ARG CI_GO_IMAGE
FROM ${CI_GO_IMAGE}

# ensure the only toolchain used to compile is the one provided by CI_GO_IMAGE
ENV GOTOOLCHAIN=local
```

The Go version can be overridden if desired:

```yaml
with:
    go-version: '1.25'
```
