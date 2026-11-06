#!/usr/bin/env bash
# Builds the development branch: the tip of the production branch plus every
# open, non-draft pull request into it.
#
# Pull requests are merged one by one in ascending number, each with its own
# merge commit, so an older pull request always gets in before a newer one
# that conflicts with it. A pull request that does not merge is rolled back
# and skipped, and the ones after it carry on. A pull request from a fork is
# skipped: the bot builds only branches of this repository.
#
# The build is left as a detached HEAD in a new worktree at <directory>; the
# caller pushes and deploys it. The composition goes to the run summary.
#
# Reads PRODUCTION_BRANCH from the environment, and GH_TOKEN / GH_REPO for gh.
# When GITHUB_OUTPUT is set, writes `head=<build commit>` and
# `fork_prs=<numbers separated by spaces>` to it.
#
# Usage: scripts/ci/build-development.sh <directory>

set -euo pipefail

directory="${1:-}"

if [[ -z "$directory" ]]; then
  echo "Usage: $0 <directory>" >&2
  exit 64
fi

if [[ -z "${PRODUCTION_BRANCH:-}" ]]; then
  echo "PRODUCTION_BRANCH is not set" >&2
  exit 64
fi

summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

# One line per open pull request into production, oldest first:
# number, draft, from a fork, head commit, head branch, title.
pulls="$(gh pr list --base "$PRODUCTION_BRANCH" --state open --limit 1000 \
  --json number,isDraft,isCrossRepository,headRefOid,headRefName,title \
  --jq 'sort_by(.number)[] | [.number, .isDraft, .isCrossRepository, .headRefOid, .headRefName, .title] | @tsv')"

candidates=()
drafts=()
forks=()
declare -A head_sha head_branch head_title

while IFS=$'\t' read -r number draft from_fork sha branch title; do
  [[ -z "$number" ]] && continue
  head_sha[$number]="$sha"
  head_branch[$number]="$branch"
  head_title[$number]="$title"
  if [[ "$draft" == true ]]; then
    drafts+=("$number")
  elif [[ "$from_fork" == true ]]; then
    forks+=("$number")
  else
    candidates+=("$number")
  fi
done <<< "$pulls"

# refs/pull/<N>/head is the head of the pull request whatever its branch is
# called; one fetch brings all of them.
refspecs=("+refs/heads/${PRODUCTION_BRANCH}:refs/remotes/origin/${PRODUCTION_BRANCH}")
for number in "${candidates[@]}"; do
  refspecs+=("+refs/pull/${number}/head:refs/remotes/pull/${number}")
done
git fetch --quiet --no-tags origin "${refspecs[@]}"

base="$(git rev-parse "refs/remotes/origin/${PRODUCTION_BRANCH}")"
git worktree add --quiet --detach "$directory" "$base"

included=()
conflicts=()

for number in "${candidates[@]}"; do
  # The head may have moved since the list was read; show what was merged.
  head_sha[$number]="$(git rev-parse "refs/remotes/pull/${number}")"
  if git -C "$directory" merge --quiet --no-ff --no-edit \
    -m "Merge pull request #${number} from ${head_branch[$number]}" \
    "refs/remotes/pull/${number}" > /dev/null 2>&1; then
    included+=("$number")
  else
    git -C "$directory" merge --abort 2> /dev/null || git -C "$directory" reset --quiet --hard HEAD
    conflicts+=("$number")
  fi
done

head="$(git -C "$directory" rev-parse HEAD)"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "head=${head}"
    echo "fork_prs=${forks[*]}"
  } >> "$GITHUB_OUTPUT"
fi

# Prints one summary line per pull request number given.
print_pulls() {
  local number
  for number in "$@"; do
    echo "- #${number} ${head_title[$number]} (\`${head_branch[$number]}\` at \`${head_sha[$number]::7}\`)"
  done
}

{
  echo "### Development build \`${head::7}\`"
  echo
  echo "From \`${PRODUCTION_BRANCH}\` at \`${base::7}\`."
  echo
  echo "**On staging** (${#included[@]}):"
  echo
  if ((${#included[@]})); then print_pulls "${included[@]}"; else echo "- none"; fi
  if ((${#conflicts[@]})); then
    echo
    echo "**Skipped, does not merge** (${#conflicts[@]}):"
    echo
    print_pulls "${conflicts[@]}"
  fi
  if ((${#forks[@]})); then
    echo
    echo "**Skipped, from a fork** (${#forks[@]}):"
    echo
    print_pulls "${forks[@]}"
  fi
  if ((${#drafts[@]})); then
    echo
    echo "**Drafts, not built** (${#drafts[@]}):"
    echo
    print_pulls "${drafts[@]}"
  fi
  echo
} >> "$summary"
