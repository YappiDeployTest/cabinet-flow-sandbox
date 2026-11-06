#!/usr/bin/env bash
# Builds and deploys the checked-out commit to one environment.
#
# This is the sandbox copy: it deploys nothing and only reports in the run
# summary what it would deploy. The Student Cabinet keeps its own copy with
# the real build and rsync.
#
# Usage: scripts/ci/deploy.sh <staging|production>

set -euo pipefail

environment="${1:-}"

case "$environment" in
  staging | production) ;;
  *)
    echo "Usage: $0 <staging|production>" >&2
    exit 64
    ;;
esac

summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

{
  echo "### Deploy to ${environment} (sandbox, nothing deployed)"
  echo
  echo "Would deploy commit \`$(git rev-parse --short HEAD)\`: $(git log -1 --format=%s)"
} >> "$summary"
