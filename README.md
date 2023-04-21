# Actions

> reusable GitHub actions across several projects

## Workflows

### Ko build

Generic build for containerised Go applications with [Ko](https://ko.build) and signing the container images with [cosign](https://docs.sigstore.dev/cosign/overview/)

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

Features
- dynamic build of images based on entrypoints (where there is a `package main`), unless if _inputs.paths_ is set
- sign with Cosign
  - image
  - SBOM
- fast!
