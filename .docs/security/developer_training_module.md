# Yggdrasil Developer Training Module (Phase 3 Enablement)

**Audience:** Control-plane engineers, realm authors, DevOps, and AppSec reviewers.  
**Format:** 2 half-days (remote-friendly), hands-on labs tied to the repo and CI.

---

## Agenda Overview
**Day 1 (Foundations)**
1. Secure architecture & threat modeling recap (STRIDE decisions).
2. Secrets & identity: JWT vs mTLS, Redis ACL, network segmentation.
3. Input validation & output encoding workshop.
4. Supply chain: SBOMs, SCA, and container scanning.

**Day 2 (Applied)**
1. Secure-by-default Express/FastAPI skeletons.
2. Writing security unit tests and header snapshot tests.
3. CI gates: tuning Semgrep, Trivy thresholds, secret scanning.
4. Operating DAST_MODE safely in staging.

---

## Labs
- **Lab 1 — Service AuthN:** Implement `requireJwt('flag-oracle')` in Gatekeeper and add unit tests for aud/iss/exp failures.
- **Lab 2 — Redis ACL:** Configure ACL so only Flag-Oracle can read/write `progress:*`. Write a test that unauthorized access fails.
- **Lab 3 — SSRF Guard (Control Plane):** Add allowlist to proxy layer; show test cases that block 169.254.169.254 and RFC1918 ranges.
- **Lab 4 — Header Harness:** Add Helmet + custom CSP; create Jest tests ensuring headers are present.
- **Lab 5 — CI Scans:** Run Semgrep locally and fix a failing rule; generate CycloneDX SBOM; run Trivy on local image.
- **Lab 6 — DAST_MODE:** Spin up staging with `ENV=staging`, `DAST_MODE=true`. Verify rate limiting and audit IDs appear in logs.

---

## Assessment & Completion
- Short quiz (15 questions).
- Code kata submission PR (contains Lab 1–4 changes) passing CI gates.
- Badge issuance in the repo’s CONTRIBUTORS.md upon completion.

---

## Resources
- `/coding_standards/secure_coding_handbook.md`
- `/config/semgrep.yml`, `/config/.pre-commit-config.yaml`
- Sample service skeletons in repo templates (to be generated in main repo).