# Contributing to Kademos Yggdrasil

## Workflow
- Create feature branches from `main` using Conventional Commits.
- Open PRs with linked issue; fill risk analysis box.
- All control-plane changes require **2 approvals** (Owner + AppSec).

## Pre-commit
Run `pre-commit install`. Commits must pass Black/Flake8/ESLint, Gitleaks, and Semgrep.

## Security Review
- Any change touching auth/crypto/proxy requires AppSec sign-off.
- New third-party packages require SCA review and SBOM update.

## DAST_MODE
- Never enable outside staging. PRs that touch DAST_MODE boot logic require SRE review.

## Licensing
- Realm content may pull vulnerable libraries intentionally; mark justifications in `realms/*/VULN_LICENSE.txt`.