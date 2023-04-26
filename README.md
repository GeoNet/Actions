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

## Other documentation

### Container image signing

Container images and their SBOMs are signed to prove and verify that they were built in a trusted environment by us.

See security supply chain related artifacts for an image:

```yaml
cosign tree IMAGE_REF

# e.g:
cosign tree registry.k8s.io/pause:3.9
```

Verify a signed image:

```yaml
cosign verify IMAGE_REF --certificate-identity-regexp "https://github.com/GeoNet/Actions/.github/workflows/reusable-(docker|ko-)([-])?build.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

View the SPXD-JSON formatted SBOM:

```yaml
cosign verify-attestation IMAGE_REF --certificate-identity-regexp "https://github.com/GeoNet/Actions/.github/workflows/reusable-(docker|ko|)([-])?build.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" | jq -r .payload | base64 -d | jq -r .predicate.Data
```

for more information, see https://docs.sigstore.dev

