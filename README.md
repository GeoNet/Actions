<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Actions](#actions)
- [Workflows](#workflows)
- [Ko build](#ko-build)
- [Ko build container image signing](#ko-build-container-image-signing)
- [Pushing to quay.io](#pushing-to-quayio)
- [Docker build](#docker-build)
- [Docker build container image signing](#docker-build-container-image-signing)
- [Pushing to quay.io](#pushing-to-quayio-1)
- [Container image promotion](#container-image-promotion)
- [Pushing to quay.io](#pushing-to-quayio-2)
- [Container image scan](#container-image-scan)
- [Update Go version](#update-go-version)
- [Terraform management](#terraform-management)
- [GitHub repo fork sync](#github-repo-fork-sync)
- [Presubmit Actions workflow require commit digest vet](#presubmit-actions-workflow-require-commit-digest-vet)
- [Presubmit Go code lint](#presubmit-go-code-lint)
- [Go vet](#go-vet)
- [Go fmt](#go-fmt)
- [Go test](#go-test)
- [Go vulnerability check](#go-vulnerability-check)
- [Presubmit commit policy conformance](#presubmit-commit-policy-conformance)
- [Stale submission](#stale-submission)
- [Go container app](#go-container-app)
- [Other documentation](#other-documentation)
- [Container image signing](#container-image-signing)
- [Versioning for container images](#versioning-for-container-images)

<!-- markdown-toc end -->

# Actions

> reusable GitHub actions across several projects

## Workflows

### Ko build

Generic build for containerised Go applications with [Ko](https://ko.build) and signing the container images and SBOMs with [cosign](https://docs.sigstore.dev/cosign/overview/)

Example:
```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  contents: write
  pull-requests: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-ko-build.yml@main
    # with:
    #   paths: ./cmd/coolapp
```

- dynamic build of images based on entrypoints (where there is a `package main`), unless if _inputs.paths_ is set
- sign with Cosign
  - image
  - SBOM
- fast!

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-ko-build.yml](.github/workflows/reusable-ko-build.yml).

#### Ko build container image signing

see [container image signing](#container-image-signing).

#### Pushing to quay.io

this has not been implemented yet and only supports pushing to ghcr.io (GitHub Container Registry), see internal discussion [here](https://github.com/GeoNet/tickets/issues/12418).

### Docker build

Generic container image build with Docker and signing container images and SBOMs with [cosign](https://docs.sigstore.dev/cosign/overview/)

Single use example:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  contents: write
  pull-requests: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: .
      dockerfile: ./Dockerfile
      imageName: cool
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref_name == 'main' }}
```

to add more, copy the block like `jobs.build` and replace values in next block where desired.

Multiple dynamic parallel builds based on directory subfolders:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  contents: write
  pull-requests: write
  id-token: write

env:
  FOLDER: apps

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set.outputs.matrix }}
    steps:
      - uses: actions/checkout@v3
      - uses: GeoNet/yq@bbe305500687a5fe8498d74883c17f0f06431ac4 # master
      - id: set
        run: |
          echo "matrix=$(find $FOLDER -mindepth 1 -maxdepth 1 -type d | xargs -n 1 basename | xargs | yq 'split(" ")|.[]|{"target":.}' -ojson | jq -rcM -s .)" >> $GITHUB_OUTPUT
      - name: check output
        run: |
          jq . <<< '${{ steps.prepare.outputs.matrix }}'

  build:
    needs: prepare
    strategy:
      matrix:
        include: ${{ fromJSON(needs.prepare.outputs.matrix) }}
    uses: GeoNet/Actions/.github/workflows/reusable-build.yml@main
    with:
      context: apps/${{ fromJSON(toJSON(matrix)).target }}
      dockerfile: apps/${{ fromJSON(toJSON(matrix)).target }}/Dockerfile
      imageName: ${{ fromJSON(toJSON(matrix)).target }}
      platforms: 'linux/amd64,linux/arm64'
```

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-docker-build.yml](.github/workflows/reusable-docker-build.yml).

#### Docker build container image signing

see [container image signing](#container-image-signing).

#### Pushing to quay.io

in the target repo, set the actions secrets (repo -> Settings -> Security -> Secrets and variables -> Actions) `QUAY_USERNAME` and `QUAY_ROBOT_TOKEN`, then set the input (under `with`) for `registryOverride` to `quay.io/geonet`

### Container image promotion

Promote container images from digests to tags.

```yaml
name: container image promotion

on:
  push:
    paths:
      - images/config.yaml
  schedule:
    - cron: "0 0 * * MON"
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-container-image-promotion.yml@main
    with:
      configPath: ./path/to/config.yaml
    #   registryOverride: quay.io/geonet
```

with a config.yaml in the format of

```yaml
- name: coolest-serverless-app
  dmap:
    "sha256:8246383b7fd0ca87cbac28e6b99d84cda5487f0e80d2c93f16c2f42366160a40": ["v1", "v1.0", "v1.0.0"]
- name: mission-critical-service
  dmap:
    "sha256:a479f33cb7f5fe7d5149de44848bcbc38d5f107d7b47a962df7749259eef49eb": ["v1"]
    "sha256:84f35de222e8a598dcb8c4cd6ad60df93360a020c6a0647c2500735683d01944": ["2023-04-24", "v2.3.1"]
- name: webthingy
  dmap:
    "sha256:efdb4ab576f4028e8319733890af8e7c49eed7f43bfe33e078052a1d0763ef89": ["v1"]
    "sha256:f0f843ca0c2b55210555af3f929b3d6ecd156485acc6eaefa59f6f11468b6061": ["2023-04-24", "v1.0.1"]
```

name being the image name under the $REGISTRY, keys under dmap being the digests to use and it's content being an array of tags to push to.

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-container-image-promotion.yml](.github/workflows/reusable-container-image-promotion.yml).

for more information, read the [versioning for container images info](#versioning-for-container-images)

format implementation inspired by [Kubernetes sig-release promotion tools](https://github.com/kubernetes-sigs/promo-tools).

#### Pushing to quay.io

in the target repo, set the actions secrets (repo -> Settings -> Security -> Secrets and variables -> Actions) `QUAY_USERNAME` and `QUAY_ROBOT_TOKEN`, then set the input (under `with`) for `registryOverride` to `quay.io/geonet`

### Container image scan

Scan a (set of) container image(s) and upload the results to GitHub's Security code scanning center.

Basic usage (non-integrated):

```yaml
name: scan

on:
  push: {}
  workflow_dispatch: {}

permissions:
  security-events: write

jobs:
  scan:
    uses: GeoNet/Actions/.github/workflows/reusable-container-image-scan.yml@main
    with:
      imageRefs: alpine:3.17,postgres:15
```

`inputs.imageRefs` is a comma separated list of container image refs.

### Update Go version

Automatically create a PR to update a project's required Go version to the latest

Example:

```yaml
name: update-go-version

on:
  workflow_dispatch: {}
  schedule:
    - cron: "0 0 * * MON"

permissions:
  contents: write
  pull-requests: write

jobs:
  update-go-version:
    uses: GeoNet/Actions/.github/workflows/reusable-update-go-version.yml@main
    with:
      modfile: go.mod
```

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-update-go-version.yml](.github/workflows/reusable-update-go-version.yml).

Works great along side [reusable ko build](#ko-build).

### Terraform management

Trigger a `terraform plan` (and optionally `terraform apply`) against Terraform located in the repo, starting at the repo root.

Example:
```yaml
name: terraform

on:
  pull_request: {}
  workflow_dispatch: {}

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-terraform-management.yml@main
    secrets: inherit
    # with:
    #   allowApply: true
```

for Terraform Cloud, set `TF_API_TOKEN` in the repo's Actions Secrets

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-terraform-management.yml](.github/workflows/reusable-terraform-management.yml).

### GitHub repo fork sync

Declaratively and automatically synchronise forked GitHub repositories inside the org.
Configuration is managed in [config/fork-sync.yaml](./config/fork-sync.yml), in a format like

```yaml
repos:
  - name: GeoNet/<NAME>
```

The sync functionality is reusable through [.github/workflows/reusable-github-repo-fork-sync.yml](./.github/workflows/reusable-github-repo-fork-sync.yml)

### Presubmit Actions workflow require commit digest vet

Require Actions to use external actions by their commit digest on presubmit pull requests

```yaml
name: Presubmit Actions workflow require commit digest vet

on:
  pull_request:
    branches:
      - main
  workflow_dispatch: {}

jobs:
  presubmit-workflow:
    uses: GeoNet/Actions/.github/workflows/reusable-presubmit-actions-workflow-require-commit-digest-vet.yml@main
```

### Presubmit Go code lint

Require pull requests for Go projects to have no linting errors

```yaml
name: Presubmit golangci lint
on:
  workflow_dispatch: {}
  push:
    branches:
      - main
      - master
      - canon
  pull_request: {}
permissions:
  contents: read
  pull-requests: read
jobs:
  golangci:
    uses: GeoNet/Actions/.github/workflows/reusable-golangci-lint.yml@main
    # with:
    #   config: |
    #     linters:
    #       enable:
    #         - gosec
    #         - funlen
    #         - depguard
    #         - whitespace
```

Standard `golangci-lint` config comes from the _.golangc-lint.yml_ file, which is located at the root of a repo and is pulled in with this action.
Whilst not generally recommend, this config can be override per action use, with the `config` input.

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-golangci-lint.yml](.github/workflows/reusable-golangci-lint.yml).

### Go vet

Run `go vet` against the codebase

```yaml
name: go vet
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-go-vet.yml@main
```

### Go fmt

Run `gofmt` against the codebase

```yaml
name: gofmt
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-gofmt.yml@main
```

### Go test

Run `go test` against the codebase

```yaml
name: go test
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-go-test.yml@main
```

### Go vulnerability check

Run `govulncheck` against the codebase

```yaml
name: govulncheck
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  govulncheck:
    uses: GeoNet/Actions/.github/workflows/reusable-govulncheck.yml@main
```

### Presubmit commit policy conformance

Add policy enforcement to PRs.

```yaml
name: policy conformance
on:
  pull_request:
    branches:
      - main
permissions:
  statuses: write
  checks: write
  contents: read
  pull-requests: read
jobs:
  conform:
    uses: GeoNet/Actions/.github/workflows/reusable-policy-conformance.yml@main
```

each repo where this action is applied must contain a `.conform.yaml` in the root of the repo.
Conform configuration examples:
- https://github.com/siderolabs/talos/blob/main/.conform.yaml
- https://github.com/siderolabs/conform/blob/main/.conform.yaml
- https://github.com/BobyMCbobs/sample-ko-monorepo/blob/main/.conform.yaml

here's an in-line example

```yaml
policies:
- type: commit
  spec:
    dco: true
    gpg:
      required: true
      githubOrganization: GeoNet
    spellcheck:
      locale: US
    maximumOfOneCommit: true
    header:
      length: 89
      imperative: true
      case: lower
      invalidLastCharacters: .
    body:
      required: true
    conventional:
      types:
        - chore
        - docs
        - perf
        - refactor
        - style
        - test
        - release
      scopes: [".*"]
```

common useful types of requirements:
- commit signed
- single commit
- commit contains body

links: 
- https://github.com/siderolabs/conform

### Stale submission

marks an issue or PR as stale after 90 days and then closes it after a further 30 days

```yaml
name: stale
on:
  schedule:
  - cron: '0 1 * * *'
jobs:
  stale:
    uses: GeoNet/Actions/.github/workflows/reusable-stale-submission.yaml@main
    # with:
    #   days-before-stale: number
    #   days-before-close: number
```

### Go container app

a workflow which combines the following workflows
- ko-build
- container-image-scan
- gofmt
- golangci-lint
- go-test
- go-vet
- image-promotion
- update-go-version
- govulncheck

```yaml
name: go container apps

on:
  push: {}
  pull_request: {}
  schedule:
    - cron: "0 0 * * *"
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  actions: read
  packages: write
  contents: write
  pull-requests: write
  id-token: write
  security-events: write
  statuses: write
  checks: write

jobs:
  go-container-apps:
    uses: BobyMCbobs/sample-ko-monorepo/.github/workflows/reusable-go-container-apps.yml@main
    # with:
    #   registryOverride: string
    #   paths: string
    #   imagePromotionConfigLiteral: |
    #     string
    #   imagePromotionConfigPath: string
    #   updateGoVersionAutoMerge: boolean
    #   containerScanningEnabled: boolean
```

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-go-container-apps.yml](.github/workflows/reusable-go-container-apps.yml).

## Other documentation

### Container image signing

Container images and their SBOMs are signed to prove and verify that they were built in a trusted environment by us.

See security supply chain related artifacts for an image:

```shell
cosign tree IMAGE_REF

# e.g:
cosign tree registry.k8s.io/pause:3.9
```

Verify a signed image:

```yaml
cosign verify IMAGE_REF --certificate-identity-regexp "https://github.com/GeoNet/Actions/.github/workflows/reusable-(docker|ko-)([-])?build.yml@.*" --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

View the SPXD-JSON formatted SBOM:

```yaml
cosign verify-attestation IMAGE_REF --certificate-identity-regexp "https://github.com/GeoNet/Actions/.github/workflows/reusable-(docker|ko|)([-])?build.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" | jq -r .payload | base64 -d | jq -r .predicate.Data
```

See the SBOM contents using the [`bom`](https://github.com/kubernetes-sigs/bom) utility from the Kubernetes community:

```shell
go install sigs.k8s.io/bom/cmd/bom@latest

cosign verify-attestation IMAGE_REF --certificate-identity-regexp "https://github.com/GeoNet/Actions/.github/workflows/reusable-(docker|ko|)([-])?build.yml@.*" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" | jq -r .payload | base64 -d | jq -r .predicate.Data | bom document outline -
```

for more information, see https://docs.sigstore.dev

### Versioning for container images

Container registries utilise content addressed storage, meaning to get some data (blob, image), you must request what it's digest is (the process behind tags).
When pushing images using the reusable Docker or Ko builds, the images will always be tagged as latest or their digest.
In order to precisely tag a container image, use the image promotion action.

The digests for images are able to be found with:

```shell
crane digest IMAGE_REF
```

or in the logs of the workflow run.

With the image promotion action, versions are able to be pinned with tags in a declarative way.
This method is much safer than more traditional options with using the affects of `docker tag SRC DEST` and secure supply chain related artifacts are automatically resolved from the digest (no need to generate or sign the new tag).
