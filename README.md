# cabinet-flow-sandbox

A rehearsal ground for the Student Cabinet's branch, staging and release flow. The workflows and scripts are debugged here and then copied into the Cabinet. There is no Cabinet code in this repository: `content/` holds plain text files to build merge conflicts from, and `package.json` has `lint`, `build` and `test` scripts that always succeed.

## Moving to the Cabinet

`.github/workflows/` and `scripts/ci/` are copied without edits, except `scripts/ci/deploy.sh <staging|production>`: the Cabinet's copy runs the real build and rsync, this one only writes to the run summary what it would deploy. The Cabinet keeps its own `package.json`. Everything else that differs between the two repositories is read from repository variables:

| Variable | Value |
|---|---|
| `PRODUCTION_BRANCH` | `production` |
| `DEVELOPMENT_BRANCH` | `development` |
| `RELEASE_TEAM` | `cabinet-releasers` |
| `NOT_ON_STAGING_LABEL` | `not-on-staging` |

## Pull request checks

`.github/workflows/pr-checks.yml` runs `npm run lint`, `npm run build` and `npm test` on every pull request into `PRODUCTION_BRANCH`, each as its own status check: `lint`, `build`, `test`.
