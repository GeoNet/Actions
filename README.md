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
      - uses: mikefarah/yq@master
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
