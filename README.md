<!-- generate TOC using `go run sigs.k8s.io/mdtoc@latest --inplace README.md` -->
<!-- toc -->
- [Actions](#actions)
  - [Workflows](#workflows)
    - [Ko build](#ko-build)
    - [Docker build](#docker-build)
    - [Dockerfile lint](#dockerfile-lint)
    - [Container image scan](#container-image-scan)
    - [Terraform management](#terraform-management)
    - [Presubmit Actions workflow require commit digest vet](#presubmit-actions-workflow-require-commit-digest-vet)
    - [Presubmit Go code lint](#presubmit-go-code-lint)
    - [Go vet](#go-vet)
    - [Go fmt](#go-fmt)
    - [Go test](#go-test)
    - [Go vulnerability check](#go-vulnerability-check)
    - [Go build smoke test](#go-build-smoke-test)
    - [goimports](#goimports)
    - [Presubmit commit policy conformance](#presubmit-commit-policy-conformance)
    - [Go container apps](#go-container-apps)
    - [Go apps](#go-apps)
    - [Bash shellcheck](#bash-shellcheck)
    - [Presubmit README table of contents](#presubmit-readme-table-of-contents)
    - [Presubmit GitHub Actions workflow validator](#presubmit-github-actions-workflow-validator)
    - [GitHub Actions action validator](#github-actions-action-validator)
    - [Markdown lint](#markdown-lint)
    - [Copy to S3](#copy-to-s3)
    - [Clean container versions](#clean-container-versions)
    - [ESLint](#eslint)
    - [AWS deploy](#aws-deploy)
  - [Composite Actions](#composite-actions)
    - [Tagging](#tagging)
    - [Validate bucket URI](#validate-bucket-uri)
    - [Copy to S3](#copy-to-s3-1)
  - [Other documentation](#other-documentation)
    - [Dependabot and Actions workflow imports](#dependabot-and-actions-workflow-imports)
    - [Versioning for container images](#versioning-for-container-images)
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

the workflows are intended to work with and around the maintainers of GeoNet software for automations which are valuable to the project.

<!-- TEMPLATE

### <NAME>

STATUS: <deprecated|alpha|beta|stable>

<DESCRIPTION AND PURPOSE>

Example:

\```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-WORKFLOW-FILE-NAME.yml@main
    # with:
    #   KEY: VALUE
\```

<ADDITIONAL INFORMATION>
<ADDITIONAL EXTERNAL CONFIG EXAMPLE>

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-WORKFLOW-FILE-NAME.yml](.github/workflows/reusable-WORKFLOW-FILE-NAME.yml).

-->

### Ko build

STATUS: stable

Generic build for containerised Go applications with [Ko](https://ko.build).

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
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-ko-build.yml@main
    # with:
    #   paths: ./cmd/coolapp
    #   registryOverride: registry.example.com
    #   registryGhcrUsernameOverride: ${{ secrets.GHCR_USERNAME }}
    #   registryGhcrPasswordOverride: ${{ secrets.GHCR_PASSWORD }}
    #   push: true
    #   aws-region: ap-southeast-2
    #   aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-ROLE_NAME
    #   aws-role-duration-seconds: "3600"
    #   setup: |
    #     sudo apt install -y something-needed-for-build
    #   configPath: .ko.yaml
```

- dynamic build of images based on entrypoints (where there is a `package main`), unless if _inputs.paths_ is set
- fast!

Pushing to ECR example:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-ko-build.yml@main
    with:
      registryOverride: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
      aws-region: ap-southeast-2
      aws-role-arn-to-assume: arn:aws:iam::$ACCOUNT:role/$ROLE_NAME
      aws-role-duration-seconds: "3600"
```

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-ko-build.yml](.github/workflows/reusable-ko-build.yml).

### Docker build

STATUS: stable

Generic container image build with Docker.

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
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: .
      dockerfile: ./Dockerfile
      imageName: cool
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref == 'refs/heads/main' }}
      buildArgs: |
        VERSION=${{ github.sha }}
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
          jq . <<< '${{ steps.set.outputs.matrix }}'

  build:
    needs: prepare
    strategy:
      matrix:
        include: ${{ fromJSON(needs.prepare.outputs.matrix) }}
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: apps/${{ fromJSON(toJSON(matrix)).target }}
      dockerfile: apps/${{ fromJSON(toJSON(matrix)).target }}/Dockerfile
      imageName: ${{ fromJSON(toJSON(matrix)).target }}
      platforms: 'linux/amd64,linux/arm64'
```

Pushing to ECR example:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: .
      dockerfile: ./Dockerfile
      imageName: cool
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref == 'refs/heads/main' }}
      registryOverride: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
      aws-region: ap-southeast-2
      aws-role-arn-to-assume: arn:aws:iam::$ACCOUNT:role/$ROLE_NAME
      aws-role-duration-seconds: "3600"
```

Pulling in a GitHub artifact for a build:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  prepare:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@c85c95e3d7251135ab7dc9ce3241c5835cc595a9 # v3.5.3
      - run: |
          mkdir -p ./apps/cool-ng/assets
          echo 'hello!' > ./apps/cool-ng/assets/index.html
      - name: upload the cool numbers
        uses: actions/upload-artifact@0b7f8abb1508181956e8e162db84b466c27e18ce # v3.1.2
        with:
          name: cool-ng
          path: ./apps/cool-ng/assets
          retention-days: 1
  build:
    needs: prepare
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: ./apps/cool-ng
      dockerfile: ./apps/cool-ng/Dockerfile
      imageName: cool-ng
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref == 'refs/heads/main' }}
      artifact-name: cool-ng
      artifact-path: ./apps/cool-ng/assets
```

Pulling in things from S3 in a build:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  copy-from-s3:
    uses: GeoNet/Actions/.github/workflows/reusable-copy-to-s3.yml@main
    with:
      aws-region: ap-southeast-2
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-ROLE_NAME
      aws-role-duration-seconds: 3600
      artifact-name: cool-ng
      artifact-path: ./apps/cool-ng/assets
      s3-bucket: s3://some-really-really-cool-s3-bucket/assets
      cp-or-sync: cp
      direction: from # 'to' or 'from'
  build:
    needs: copy-from-s3
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: ./apps/cool-ng
      dockerfile: ./apps/cool-ng/Dockerfile
      imageName: cool-ng
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref == 'refs/heads/main' }}
      artifact-name: cool-ng
      artifact-path: ./apps/cool-ng/assets
```

note: $registryOverride + '/' + $imageName must be an existing ECR

Override auth to ghcr.io

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: .
      dockerfile: ./Dockerfile
      imageName: cool
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref == 'refs/heads/main' }}
      buildArgs: |
        VERSION=${{ github.sha }}
      registryGhcrUsernameOverride: example
    secrets: inherit
```

Copy an image to a different container registry:

```yaml
name: build

on:
  push: {}
  release:
    types: [published]
  workflow_dispatch: {}

permissions:
  packages: write
  id-token: write

env:
  VERSION_CRANE: v0.16.1

jobs:
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      context: .
      dockerfile: ./Dockerfile
      imageName: cool
      platforms: 'linux/amd64,linux/arm64'
      push: ${{ github.ref == 'refs/heads/main' }}
  copy-image-to-registry:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: GeoNet/setup-crane@00c9e93efa4e1138c9a7a5c594acd6c75a2fbf0c # main
        with:
          version: ${{ env.VERSION_CRANE }}
      - name: authenticate to registry
        run: |
          echo SOME_PASSWORD | crane auth login -u some-user --password-stdin
      - name: copy image
        env:
          SOURCE: ${{ needs.build.outputs.image }}
          DESTINATION: ghcr.io/someorg/someimage:sometag
        run: |
          crane cp "$SOURCE" "$DESTINATION"
```

this may be useful for things like image promotion or staging.

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-docker-build.yml](.github/workflows/reusable-docker-build.yml).

### Dockerfile lint

STATUS: stable

```yaml
name: dockerfile lint
on:
  pull_request: {}
  workflow_dispatch: {}
jobs:
  dockerfile-lint:
    uses: GeoNet/Actions/.github/workflows/reusable-dockerfile-lint.yml@main
    with:
    #   dockerfiles: |
    #     ...
```

### Container image scan

STATUS: stable

Scan a (set of) container image(s) and upload the results to GitHub's Security code scanning center

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

### Terraform management

STATUS: stable

Trigger a `terraform plan` (and optionally `terraform apply`) against Terraform located in the repo, starting at the repo root

Example:

```yaml
name: terraform

on:
  pull_request: {}
  workflow_dispatch: {}

jobs:
  terraform:
    uses: GeoNet/Actions/.github/workflows/reusable-terraform-management.yml@main
    secrets: inherit
    # with:
    #   allowApply: true
```

for Terraform Cloud, set `TF_API_TOKEN` in the repo's Actions Secrets

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-terraform-management.yml](.github/workflows/reusable-terraform-management.yml).

### Presubmit Actions workflow require commit digest vet

STATUS: stable

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

STATUS: stable

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

STATUS: stable

Run `go vet` against the codebase for static code analysis

```yaml
name: go vet
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  go-vet:
    uses: GeoNet/Actions/.github/workflows/reusable-go-vet.yml@main
```

### Go fmt

STATUS: stable

Run `gofmt` against the codebase to format the Go code

```yaml
name: gofmt
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  gofmt:
    uses: GeoNet/Actions/.github/workflows/reusable-gofmt.yml@main
```

### Go test

STATUS: stable

Run `go test` against the codebase to run unit tests

```yaml
name: go test
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  go-test:
    uses: GeoNet/Actions/.github/workflows/reusable-go-test.yml@main
```

test coverage results upload to job artifacts, found at the bottom of a job summary page.

### Go vulnerability check

STATUS: stable

Run `govulncheck` against the codebase to scan and report vulnerable packages in use

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

### Go build smoke test

STATUS: stable

Performs `go build -o /dev/null $PATH` to ensure that the programs compile

Example:

```yaml
name: go build smoke test

on:
  push: {}
  workflow_dispatch: {}

jobs:
  go-build-smoke-test:
    uses: GeoNet/Actions/.github/workflows/reusable-go-build-smoke-test.yml@main
    # with:
    #   paths: ./cmd/coolapp
```

Note: does not cache or push the binary artifacts anywhere.

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-go-build-smoke-test.yml](.github/workflows/reusable-go-build-smoke-test.yml).

### goimports

STATUS: stable

Run `goimports` against the codebase to ensure that the imports are structured correctly

```yaml
name: goimports
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  goimports:
    uses: GeoNet/Actions/.github/workflows/reusable-goimports.yml@main
```

### Presubmit commit policy conformance

STATUS: stable

Checks commits in PRs for agreed qualities, such as conventionalcommits and style

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
jobs:
  conform:
    uses: GeoNet/Actions/.github/workflows/reusable-policy-conformance.yml@main
```

each repo where this action is applied must contain a `.conform.yaml` in the root of the repo.
Conform configuration examples:

- <https://github.com/siderolabs/talos/blob/main/.conform.yaml>
- <https://github.com/siderolabs/conform/blob/main/.conform.yaml>
- <https://github.com/BobyMCbobs/sample-ko-monorepo/blob/main/.conform.yaml>

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
        - feat
        - fix
        - nfc
      scopes: [".*"]
```

common useful types of requirements:

- commit signed
- single commit
- commit contains body

notes:

- the conventional types include the following types by default and are not needed to be specified
  - _feat_
  - _fix_

links:

- <https://github.com/siderolabs/conform>
- <https://www.conventionalcommits.org/en/v1.0.0/>

### Go container apps

STATUS: stable

a workflow which combines the following workflows

- ko-build
- go-build-smoke-test
- container-image-scan
- gofmt
- golangci-lint
- go-test
- go-vet
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
    uses: GeoNet/Actions/.github/workflows/reusable-go-container-apps.yml@main
    # with:
    #   registryOverride: string
    #   paths: string
    #   imagePromotionConfigLiteral: |
    #     string
    #   imagePromotionConfigPath: string
    #   updateGoVersionAutoMerge: boolean
    #   containerScanningEnabled: boolean
    #   containerBuildEnabled: boolean
    #   registryOverride: $ACCOUNT.dkr.ecr.$REGION.amazonaws.com
    #   aws-region: ap-southeast-2
    #   aws-role-arn-to-assume: arn:aws:iam::$ACCOUNT:role/$ROLE_NAME
    #   aws-role-duration-seconds: "3600"
    #   buildSetup: |
    #     sudo apt install -y something-needed-for-build
    #   koBuildConfigPath: .ko.yaml
```

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-go-container-apps.yml](.github/workflows/reusable-go-container-apps.yml).

### Go apps

STATUS: stable

a workflow which combines the following workflows

- go-build-smoke-test
- gofmt
- golangci-lint
- go-test
- go-vet
- update-go-version
- govulncheck

```yaml
name: go apps

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
  contents: write
  pull-requests: write
  id-token: write
  security-events: write
  statuses: write
  checks: write

jobs:
  go-apps:
    uses: GeoNet/Actions/.github/workflows/reusable-go-apps.yml@main
    # with:
    #   paths: string
    #   updateGoVersionAutoMerge: boolean
```

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-go-container-apps.yml](.github/workflows/reusable-go-container-apps.yml).

### Bash shellcheck

STATUS: stable

Runs shellcheck against all known shell scripts

```yaml
name: bash shellcheck
on:
  workflow_dispatch: {}
  push: {}
  pull_request: {}
jobs:
  bash-shellcheck:
    uses: GeoNet/Actions/.github/workflows/reusable-bash-shellcheck.yml@main
```

### Presubmit README table of contents

STATUS: stable

Ensure that the table of contents is updated in README.md, when sections and titles are modified

```yaml
name: presubmit README table of contents
on:
  pull_request: {}
  workflow_dispatch: {}
jobs:
  presubmit-readme-toc:
    uses: GeoNet/Actions/.github/workflows/reusable-presubmit-readme-toc.yml@main
```

**important** to note: a markdown file must contain the following

```text
<!-- generate TOC using `go run sigs.k8s.io/mdtoc@latest --inplace README.md` -->
<!-- toc -->
<!-- /toc -->
```

given a markdown file (e.g: `README.md`) and the contents above included
in the markdown file, the table of contents can be generated with the command
in that comment:

```shell
go run sigs.k8s.io/mdtoc@latest --inplace README.md
```

note: requires Go to be installed

### Presubmit GitHub Actions workflow validator

STATUS: stable

A workflow to validate all the workflows in the repo

```yaml
name: presubmit GitHub Actions workflow validator
on:
  pull_request: {}
  workflow_dispatch: {}
jobs:
  presubmit-github-actions-workflow-validator:
    uses: GeoNet/Actions/.github/workflows/reusable-presubmit-github-actions-workflow-validator.yml@main
```

### GitHub Actions action validator

STATUS: stable

A workflow to validate a GitHub action (not reusable workflow)

```yaml
name: presubmit GitHub Actions action validator
on:
  pull_request: {}
  workflow_dispatch: {}
jobs:
  presubmit-github-actions-action-validator:
    uses: GeoNet/Actions/.github/workflows/reusable-github-actions-action-validator.yml@main
    with:
      actionPaths: ./action.yml
```

### Markdown lint

STATUS: stable

Lints markdown files

```yaml
name: lint markdown
on:
  pull_request: {}
  workflow_dispatch: {}
jobs:
  lint-markdown:
    uses: GeoNet/Actions/.github/workflows/reusable-markdown-lint.yml@main
    # with:
    #   ignore: some-folder
```

### Copy to S3

STATUS: stable

A workflow to copy or sync a local directory to an S3 bucket

```yaml
name: copy to s3
on:
  push:
    branches:
      - main
  workflow_dispatch: {}
permissions:
  id-token: write
  contents: read
jobs:
  copy-to-s3:
    uses: GeoNet/Actions/.github/workflows/reusable-copy-to-s3.yml@main
    with:
      aws-region: ap-southeast-2
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-ROLE_NAME
      aws-role-duration-seconds: 3600
      # aws-role-session-name:
      local-source-dir: ./result/
      destination-s3-bucket: s3://some-really-really-cool-s3-bucket
      cp-or-sync: sync # 'cp' or 'sync'
      direction: to # 'to' or 'from'
```

it is also chainable with other jobs

```yaml
name: copy to s3
on:
  push:
    branches:
      - main
  workflow_dispatch: {}
permissions:
  id-token: write
  contents: read
jobs:
  generate-cool-numbers:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab # v3.5.2
      - name: generate
        run: |
          mkdir -p ./outputs/
          echo "$RANDOM" >> ./outputs/1.txt
          echo "$RANDOM" >> ./outputs/1.txt
          echo "$RANDOM" >> ./outputs/1.txt
          echo "$RANDOM" >> ./outputs/1.txt
          echo "$RANDOM" >> ./outputs/2.txt
          echo "$RANDOM" >> ./outputs/2.txt
          echo "$RANDOM" >> ./outputs/2.txt
          echo "$RANDOM" >> ./outputs/2.txt
      - name: upload the cool numbers
        uses: actions/upload-artifact@0b7f8abb1508181956e8e162db84b466c27e18ce # v3.1.2
        with:
          name: cool-numbers
          path: ./outputs/**
          retention-days: 1
  copy-to-s3:
    needs: generate-cool-numbers
    uses: GeoNet/Actions/.github/workflows/reusable-copy-to-s3.yml@main
    with:
      aws-region: ap-southeast-2
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-ROLE_NAME
      aws-role-duration-seconds: 3600
      # aws-role-session-name:
      artifact-name: cool-numbers
      artifact-path: ./output
      destination-s3-bucket: s3://some-really-really-cool-s3-bucket
      cp-or-sync: sync # 'cp' or 'sync'
      direction: to # 'to' or 'from'
```

or copying from S3

``` yaml
name: copy from s3
on:
  workflow_dispatch: {}
permissions:
  id-token: write
  contents: read
jobs:
  copy-from-s3:
    uses: GeoNet/Actions/.github/workflows/reusable-copy-to-s3.yml@main
    with:
      aws-region: ap-southeast-2
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-ROLE_NAME
      aws-role-duration-seconds: 3600
      # aws-role-session-name:
      artifact-name: cool-numbers
      artifact-path: ./output
      s3-bucket: s3://some-really-really-cool-s3-bucket
      cp-or-sync: sync # 'cp' or 'sync'
      direction: from # 'to' or 'from'
  check-out-the-cool-numbers:
    needs: copy-from-s3
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab # v3.5.2
      - uses: actions/download-artifact@9bc31d5ccc31df68ecc42ccf4149144866c47d8a # v3.0.2
        with:
          name: cool-numbers
          path: ./output
      - run: |
          tree ./output/
```

GitHub Actions artifacts are used to bring state between jobs, this is not possible in any other known way.

for configuration see [`on.workflow_call.inputs` in .github/workflows/reusable-copy-to-s3.yml](.github/workflows/reusable-copy-to-s3.yml).

### Clean container versions

STATUS: stable

```yaml
name: clean-images
permissions:
  packages: write
on:
  schedule:
    - cron:  '30 11,23 * * *'
  workflow_dispatch: {}
jobs:
  clean:
    runs-on: ubuntu-latest
    uses: GeoNet/Actions/.github/workflows/reusable-clean-containers.yml@main
    with:
      package-name: base-images/fedora
      ignored-regex: '(stable)|(38)'
      number-kept: 7
```

### ESLint

STATUS: beta

Used to run ESLint on one or more directories. The paths specified
should have a package.json with eslint defined, alongside an eslint config
file named eslint.config.mjs.

```yaml
name: eslint
on:
  push: {}
  pull_request: {}
  workflow_dispatch: {}
jobs:
  eslint:
    uses: GeoNet/Actions/.github/workflows/reusable-eslint.yml@main
    with:
      paths: |
        ./root/folder/one
        ./cool/root/folder/two
      node-version: 22.x
```


### AWS deploy

STATUS: beta

CICD-driven container image deployment, using AWS ECR and ECS.

This workflow supports:

- ECS service deployments
- EventBridge rule target updates

No deployment can also be specified, allowing the newly created task revision to be deployed via other mechanisms.

Example:

```yaml
name: build-and-deploy

permissions:
  contents: write
  id-token: write

jobs:
  # build image
  build:
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main

  # example 1: deploy - ECS service
  deploy:
    needs: build
    uses: GeoNet/Actions/.github/workflows/reusable-aws-deploy.yml@main
    with:
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-geonet-deploy-ROLE_NAME

      # update task definition with new container image uri
      task-name: my_task_name
      container: my_task_container_name
      image: ${{ needs.build.output.image }}

      # deploy
      deployment-type: ecs
      service: my_service
      cluster: my_cluster

      # save deployment information
      deployment-tag-param-name: /deployment/my_project/my_service

  # example 2: deploy - EventBridge rule target
  deploy:
    needs: build
    uses: GeoNet/Actions/.github/workflows/reusable-aws-deploy.yml@main
    with:
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-geonet-deploy-ROLE_NAME

      # update task definition with new container image uri
      task-name: my_task_name
      container: my_task_container_name
      image: ${{ needs.build.output.image }}

      # deploy
      deployment-type: eventbridge
      rule-name: my_rule

      # save deployment information
      deployment-tag-param-name: /deployment/my_project/my_service

  # example 3: only create new task revision
  deploy:
    needs: build
    uses: GeoNet/Actions/.github/workflows/reusable-aws-deploy.yml@main
    with:
      aws-role-arn-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-geonet-deploy-ROLE_NAME

      # update task definition with new container image uri
      task-name: my_task_name
      container: my_task_container_name
      image: ${{ needs.build.output.image }}
      deployment-type: ''
```

The terraform module `gha_iam_ecs_deploy` can be used to setup appropriate permissions for this workflow.
The terraform module `ecs_docker_task_ng` can be used to configure services for use with this workflow, via the `use_cicd_deployment` variable.

Some example repos using this workflow: `DevTools` and `gloria`.


## Composite Actions

### Tagging

STATUS: stable

Generic container tagging.

Generally will be used in the reusable workflows, but if one needed to use the action directly:

```yaml
on: [push]

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      tag: steps.tagging.outputs.tag
    steps:
      - uses: actions/checkout@v4
      - id: tagging
        uses: GeoNet/Actions/.github/actions/tagging@main
  build:
    needs: prepare
    uses: GeoNet/Actions/.github/workflows/reusable-docker-build.yml@main
    with:
      tag: ${{ needs.prepare.outputs.tag }}
```

### Validate bucket URI

STATUS: beta

Validate an S3 bucket URI by checking it is in the right format and contains only valid characters.

```yaml
on: [push]

jobs:
  prepare:
    runs-on: ubuntu-latest
    steps:
      - name: Validate bucket
        uses: GeoNet/Actions/.github/actions/validate-bucket-uri@main
        with:
          s3-bucket-uri: s3://my-bucket-to-validate/my-bucket-prefix
```

### Copy to S3

STATUS: beta

Copy (or sync) one or more files from GitHub Actions Artifacts to an S3 bucket.

```yaml
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Upload test log to GitHub Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: test-coverage-results
          path: |
            /tmp/coverage.out
      - name: Upload test log to S3
        uses: GeoNet/Actions/.github/actions/copy-to-s3@main
        with:
          aws-role-arn-to-assume: my-role
          artifact-name: test-coverage-results
          artifact-path: ./coverage
          s3-bucket-uri: s3://my-bucket/test-coverage-results/
```

## Other documentation

### Dependabot and Actions workflow imports

Dependabot is enabled for this repo, see the config in [.github/dependabot.yml](./.github/dependabot.yml).
It will automatically update create PRs to update the Actions workflow imports once a week in a seemingly staggered way.

To force an update of every external import, run `hack/update-actions-imports.sh` and commit the changes in a new PR.

### Versioning for container images

Container registries utilise content addressed storage, meaning to get some data (blob, image), you must request what it's digest is (the process behind tags).
When pushing images using the reusable Docker or Ko builds, the images will always be tagged as latest or their digest.
In order to precisely tag a container image, use the image promotion action.

The digests for images are able to be found with:

```shell
crane digest IMAGE_REF
```

or in the logs of the workflow run.
