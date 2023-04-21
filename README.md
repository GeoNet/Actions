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
    uses: GeoNet/Actions/.github/workflows/reusable-terraform.yml@main
    # with:
    #   allowApply: true
```

for Terraform Cloud, set `TF_API_TOKEN` in the repo's Actions Secrets
