# Branch protections

Repos branches are protected through requiring pull requests
and passing workflow jobs. All of the GeoNet repos have some
form of branch protection, whether that be just no write to main
and/or some checks from workflows that are in those repos.

## Behaviours

GitHub Actions workflows populate the
_Require status checks to pass before merging_ section of
project settings after they're run, so a new job can't be
required for protection until it's run.

The search is unhelpful due to it not populating the list of
checks when trying to search without typing.

## GitHub tokens

A GitHub token is needed for applying branch protection.
The permissions required are:

- admin:org
- repo

## Determine a list of checks

Use the helper script to get a mostly-concreate set of values
which may be set to provide check-based branch merge protection.

The list of checks is discovered through the check suites published
by GitHub Actions against the latest pull request made by a human.

List checks for all GeoNet repos

```sh
./hack/list-checks.sh | tee /tmp/list-checks.yaml
```

and append the output to a yaml file.

List checks for a specific GeoNet repos

```sh
./hack/list-checks.sh Actions base-images
```

Some example output may look like

```yaml
GeoNet/Actions:
  - commit-digest-vet / presubmit-workflow
  - conform / conform
  - lint-markdown / markdown-lint
  - presubmit-readme-toc / presubmit-readme-toc
  - require-actions-run-from-GeoNet-org
  - require-jobs-run-steps-have-name
  - require-reusable-workflow-is-documented
  - t0-basic / build
  - t0-basic-check
  - t1-use-test / build
  - t1-use-test-check
  - t2-artifact-pull / build
  - t2-artifact-pull-cleanup
  - t2-artifact-pull-prepare
  - t3-multi-arch / build
  - t3-multi-arch-check
  - t6-auth-with-geonetci / build
  - t6-auth-with-geonetci-check
  - t7-use-setup / build
  - t8-use-tags / build
  - t8-use-tags-check
  - t9-no-push / build
  - t9-no-push-check
  - validate-schema / validate-github-actions
GeoNet/base-images:
  - conform / conform
  - presubmit-github-actions-workflow-validator / validate-github-actions
  - presubmit-image-documented
  - presubmit-image-exists
  - presubmit-image-format
  - presubmit-readme-toc / presubmit-readme-toc
```

Protection rules can be applied directly from what checks are present in the latest PR with

```sh
./hack/list-checks.sh | ./hack/set-bp-yaml-checks.sh bp-config.yaml sow
```

every subsequent time, a command such as the following should be used to only update the check contexts

```sh
./hack/list-checks.sh | ./hack/set-bp-yaml-checks.sh bp-config.yaml update
```

## Applying the checks with branchprotector

the branch protection rules are able to be applied with

`go run`:

```sh
go run k8s.io/test-infra/prow/cmd/branchprotector@acf4a2e26b --github-token-path PATH_TO_TOKEN --config-path PATH_TO_CONFIG.yaml # --confirm
```

or with the container image

```sh
podman run -it --rm \
  -v "PATH_TO_TOKEN:PATH_TO_TOKEN:row" \
  -v "PATH_TO_CONFIG:PATH_TO_CONFIG:ro" \
  gcr.io/k8s-prow/branchprotector:v20231011-acf4a2e26b \
    --github-token-path PATH_TO_TOKEN \
    --config-path PATH_TO_CONFIG.yaml # --confirm
```

ghproxy can also be used to cache the GitHub responses to save on tokens

```sh
podman run -it --rm -v ghproxy:/cache -p 8888:8888 gcr.io/k8s-prow/ghproxy:v20231011-33fbc60185 --cache-dir=/cache --cache-sizeGB=99
```

then add the following args to branchprotector

```sh
--github-endpoint=http://localhost:8888 --github-endpoint=https://github.com
```
