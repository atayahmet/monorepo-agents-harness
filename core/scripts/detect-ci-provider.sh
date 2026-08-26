#!/usr/bin/env bash
# Detect the CI provider used by the target repo.
#
# Usage (from the target repo root):
#   detect-ci-provider.sh [--provider]
#
# Output:
#   --provider   prints one of: github-actions, gitlab, bitbucket, circleci, unknown
#   default      prints "ci-provider: <name>"
#
# Detection order (first match wins, most specific marker per provider):
#   .github/workflows/        -> github-actions
#   .gitlab-ci.yml             -> gitlab
#   bitbucket-pipelines.yml    -> bitbucket
#   .circleci/config.yml       -> circleci
#
# Depends only on git + coreutils. Detection never "fails" — unknown is a valid, expected result
# for repos with no CI configured yet.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

print_provider=0
for arg in "$@"; do
  case "$arg" in
    --provider) print_provider=1 ;;
  esac
done

provider="unknown"

if [ -d "$ROOT/.github/workflows" ]; then
  provider="github-actions"
elif [ -f "$ROOT/.gitlab-ci.yml" ]; then
  provider="gitlab"
elif [ -f "$ROOT/bitbucket-pipelines.yml" ]; then
  provider="bitbucket"
elif [ -f "$ROOT/.circleci/config.yml" ]; then
  provider="circleci"
fi

if [ "$print_provider" -eq 1 ]; then
  echo "$provider"
  exit 0
fi

echo "ci-provider: $provider"
