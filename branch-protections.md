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
./hack/list-checks.sh Actions base-images | ./hack/set-checks.sh
```
