# Branch Protection (main)

Apply these settings in GitHub:

1. Go to `Settings` -> `Branches` -> `Add rule`.
2. Branch name pattern: `main`.
3. Enable:
   - `Require a pull request before merging`
   - `Require approvals` (recommended: 1+)
   - `Dismiss stale pull request approvals when new commits are pushed`
   - `Require status checks to pass before merging`
   - `Require branches to be up to date before merging`
   - `Require conversation resolution before merging`
   - `Do not allow bypassing the above settings`
4. Required status check:
   - `xcodebuild-tests` (from workflow `iOS Tests`)

Optional hardening:
- `Require signed commits`
- `Require linear history`
- `Restrict who can push to matching branches`
