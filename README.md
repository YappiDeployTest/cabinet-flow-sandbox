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
| `BOT_CLIENT_ID` | Client ID of the repository's bot GitHub App |

Secrets live in the `production` environment, which releases them only to runs started from `PRODUCTION_BRANCH`: the bot's private key `BOT_PRIVATE_KEY`, and in the Cabinet the deploy secrets `PROD_DEPLOY_KEY`, `PROD_DEPLOY_HOST`, `PROD_DEPLOY_USER`, `PROD_DEPLOY_PATH`, `PROD_DEPLOY_MANIFEST_PATH`.

## Pull request checks

`.github/workflows/pr-checks.yml` runs `npm run lint`, `npm run build` and `npm test` on every pull request into `PRODUCTION_BRANCH`, each as its own status check: `lint`, `build`, `test`.

## Release

`.github/workflows/release.yml` is started by hand only: the Run workflow button in Actions, or `gh workflow run release`. Only members of the `RELEASE_TEAM` team may run it.

- **Release** (`bump`: `patch` by default, `minor`, `major`): lints and tests the tip of `PRODUCTION_BRANCH`, runs `scripts/ci/deploy.sh production`, and after a successful deploy tags the tip `web-vX.Y.Z` and publishes a GitHub Release whose notes list the pull requests merged since the previous release. The version is the highest `web-v*` tag raised by `bump`, the first one `web-v2.0.0`; it lives only in the tag. A tip the latest release already contains is refused: there is nothing to release.
- **Dry run** (`dry_run`): writes the next version and its pull requests to the run summary; nothing is built, deployed or tagged.
- **Redeploy** (`redeploy: web-vX.Y.Z`): builds and deploys that existing tag again, without a new version or tag. This is the rollback; the fix after it is a `hotfix/` pull request and a new release.

```
gh workflow run release
gh workflow run release -f bump=minor
gh workflow run release -f dry_run=true
gh workflow run release -f redeploy=web-v2.0.0
```
