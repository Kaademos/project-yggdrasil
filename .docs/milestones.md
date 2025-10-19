# Kademos Yggdrasil — End-to-End Implementation Milestones (S‑SDLC Aligned)

> Scope: This roadmap builds the **platform** incrementally, with tight security-by-design and verification gates. Each milestone is self-contained, builds on the previous, and must be **green** before moving on.

Legend: **AC** = Acceptance Criteria, **US** = User Story, **AbS** = Abuse Story (negative), **ASVS** = OWASP Application Security Verification Standard 5.0 refs, **DoD** = Definition of Done.

---

## M0 — Repo Bootstrap & Governance (Day 0)
**Goal:** Clean repo foundation, contributor workflow, and security governance in place.

- **Deliverables**
  - Repo structure skeleton (`core/`, `realms/`, `docker/`, `config/`, `.docs/`).
  - Security docs already present in `.docs/` (ASVS map, STRIDE, DFD).
  - Branch protection + CODEOWNERS; pre-commit hooks and scanners wired.
  - CI workflow file stub created (disabled jobs may be placeholders).

- **US**
  - As a developer, I need a predictable repo layout so I can contribute without breaking security rules.

- **AbS**
  - As an attacker, I try to push secrets and insecure code to main without review.

- **AC**
  - Branch protection requires PR + 2 approvers for `/core/*` changes.
  - `pre-commit run --all-files` succeeds locally.
  - CI runs lint/scan placeholders successfully (even if build jobs are disabled).

- **ASVS**
  - V1 (architecture docs), V10 (supply chain basics), V16 (DevSecOps) — baseline checks exist.

- **DoD**
  - README includes contribution workflow and link to `.docs/`.
  - `.gitignore`/`.dockerignore` prevent noisy files; repo is clean (≤ 10 untracked files after hook install).

---

## M1 — Control Plane Skeletons (Gatekeeper + Flag-Oracle) — Local Dev
**Goal:** Minimal services compile, run locally, and expose `/healthz` with secure headers.

- **Deliverables**
  - Gatekeeper (Express or Go) service scaffold with Helmet / secure headers.
  - Flag-Oracle (FastAPI/Flask) service scaffold.
  - `docker/docker-compose.yml` (DAST_MODE=false by default).
  - **Makefile** with `make dev`, `make up`, `make down`, `make test`.

- **US**
  - As a developer, I can run both services locally with one command and get health responses.

- **AbS**
  - As an attacker, I try to access admin endpoints unauthenticated during bootstrap.

- **AC**
  - `make dev` starts services; `curl :8080/healthz` and `curl :8000/healthz` return `{ ok: true }`.
  - Helmet/CSP applied on Gatekeeper responses.
  - No critical/high CVEs in base images (scan once images exist).

- **ASVS**
  - V14 (configuration), V15 (web UI headers), V9 (communications planning).

- **DoD**
  - Unit smoke tests for `/healthz` exist and pass locally and in CI.

---

## M2 — Service Identity & AuthN (JWT or mTLS) + Redis Hardening
**Goal:** Secure, authenticated service-to-service calls with Redis-backed state store.

- **Deliverables**
  - Gatekeeper ⇄ Flag-Oracle: JWT (RS256) verification with `iss/aud/exp/nbf` checks **or** mTLS.
  - Redis container with ACL; state keyspace `progress:{user}` (Set of unlocked realms).
  - Secrets injected via environment; **no secrets in images**.
  - Unit tests for JWT/mTLS success and failure.

- **US**
  - As the platform, I must only accept state change requests from Gatekeeper.

- **AbS**
  - As an attacker inside a realm, I try to talk directly to Flag-Oracle or Redis.

- **AC**
  - `/state` and `/validate` enforce service auth; unauthenticated/invalid tokens → 401/403.
  - Redis is reachable **only** from Flag-Oracle; ACL denies other clients.
  - Tests for expired/invalid tokens pass (negative cases).

- **ASVS**
  - V2/V9 (authentication & communications), V13 (API security), V8 (data protection), V16 (DevSecOps scans).

- **DoD**
  - SAST + secret scan + container scan green; evidence archived in CI.

---

## M3 — Progression Logic & Proxy Controls (DAST_MODE=false)
**Goal:** Enforce realm progression in Gatekeeper and proxy only unlocked realms.

- **Deliverables**
  - Gatekeeper routes `/realm/:name` proxy only if user has unlocked state.
  - Flag-Oracle exposes `POST /validate` accepting `{ user, realm, flag }` and updates Redis.
  - Allowlist for proxy targets to prevent open-proxy/SSRF; block private CIDRs by default.

- **US**
  - As a learner, submitting a correct flag unlocks the next realm.

- **AbS**
  - As an attacker, I try to request a locked realm or pivot via gatekeeper proxy to internal IPs.

- **AC**
  - E2E tests simulate unlock flow: `validate → state updated → proxy allowed`.
  - Negative tests: locked realm → 403; proxy to `169.254.169.254` → blocked.
  - Logs contain `audit-correlation-id` from ingress to oracle.

- **ASVS**
  - V4 (access control), V5 (validation), V12 (files/resources), V15 (CSRF if any admin forms).

- **DoD**
  - All tests pass; Gatekeeper denies all unknown realm targets by config.

---

## M4 — DAST Staging Stack (DAST_MODE=true) + Rate Limiting + Audit
**Goal:** Safe automated scanning across all realms in staging only.

- **Deliverables**
  - `docker-compose.staging.yml` sets `ENV=staging` + `DAST_MODE=true`; refuses to start elsewhere.
  - Rate limits (stricter in DAST mode) and separate **audit log stream**.
  - ZAP baseline config `.zap/rules.tsv` + CI DAST job skeleton.
  - Evidence artifact retention (reports, logs).

- **US**
  - As a security engineer, I can scan the full surface programmatically in staging.

- **AbS**
  - As an attacker, I try to toggle DAST_MODE in production to widen attack surface.

- **AC**
  - Starting Gatekeeper with `DAST_MODE=true` outside staging fails fast.
  - Running the DAST job produces an artifact; findings in **control plane** must be zero to pass gate.

- **ASVS**
  - V16 (DevSecOps automation), V12 (resource limits), V9 (transport).

- **DoD**
  - CI DAST job runs, uploads ZAP report, and enforces control-plane zero-critical policy.

---

## M5 — Realm MVP: Niflheim (A10: SSRF) + Realm Networks
**Goal:** First realm implemented on its own bridge network; proxy path works end-to-end.

- **Deliverables**
  - `realms/niflheim` app + a hidden internal service only reachable within `niflheim_net`.
  - Gatekeeper bridges to `niflheim_net`; progression unlock required to access.
  - Realm UI: “Analytics” dashboard façade.

- **US**
  - As a learner, I can exploit SSRF to retrieve a flag and unlock the realm.

- **AbS**
  - As an attacker, I try to laterally move from Niflheim to other realm networks.

- **AC**
  - From inside Niflheim container, cannot reach other realm nets or control plane.
  - Manual walk-through confirms exploit path and progression update.
  - DAST mode scans see Niflheim endpoints when toggled ON in staging.

- **ASVS**
  - Realm intentionally violates V5 (validation) for training; document N/A-intentional.
  - Platform adheres to V1/V9/V12 around its integration.

- **DoD**
  - E2E test covers typical learner path; isolation tests pass.

---

## M6 — Realms Batch 2: Helheim (A09), Svartalfheim (A08), Jotunheim (A07)
**Goal:** Add three diverse realms; ensure UI/UX fidelity and isolation persist.

- **Deliverables**
  - Helheim (logging failures), Svartalfheim (integrity/deserialization), Jotunheim (auth/session flaws).
  - Each realm network isolated; manifests present for SCA.

- **US**
  - As a program manager, I can evaluate cross-language AST tool coverage using the monorepo.

- **AbS**
  - As an attacker, I try to leak control-plane secrets via realm logs or env.

- **AC**
  - Control-plane secrets *never* in realm env; secret scans green.
  - SCA sees expected outdated deps (noise plus true positives).

- **ASVS**
  - V10 (supply chain), V7 (logging), V3 (session).

- **DoD**
  - DAST staging job still passes zero-control-plane-findings rule.

---

## M7 — Realms Batch 3: Muspelheim (A06), Nidavellir (A05), Vanaheim (A04), Midgard (A03)
**Goal:** Add external dependencies and complexity (S3/MinIO, Postgres).

- **Deliverables**
  - Muspelheim (outdated components + XSS), Nidavellir (misconfig + S3), Vanaheim (business logic), Midgard (SQLi + Postgres).
  - Realistic seed data; Sequelize/pg or equivalent with parameterization for platform code (keep realm vulnerable patterns isolated).

- **US**
  - As a learner, I experience realistic enterprise flaws across stacks.

- **AbS**
  - As an attacker, I attempt DB pivoting from Midgard to Asgard DB.

- **AC**
  - DBs scoped only to their realms; cannot be reached inter-realm.
  - DAST picks up Midgard injection vectors (as expected).

- **ASVS**
  - V5 (validation), V8 (data at rest), V12 (file/storage), V10 (SCA).

- **DoD**
  - Isolation & resource policies documented and verified.

---

## M8 — Final Realm: Alfheim (A02) & Asgard (A01) + End-to-End Walkthrough
**Goal:** Complete all ten realms and run a full narrative walkthrough validating progression & isolation.

- **Deliverables**
  - Alfheim (crypto failures), Asgard (broken access control + chained SQLi → IDOR).
  - Full story progression implemented; challenge unlock order enforced.

- **US**
  - As a course owner, I can run the whole platform and verify learning outcomes.

- **AbS**
  - As an attacker, I chain vulnerabilities to reach other realms; isolation must block pivoting.

- **AC**
  - Full walkthrough from A10→A01 succeeds; expected flags retrieved.
  - Control-plane continues to produce zero DAST findings.

- **ASVS**
  - Documentation updates for N/A-intentional realms; control-plane remains ASVS L1/L2 compliant where applicable.

- **DoD**
  - Sign-off checklist complete; risks accepted for intentionally vulnerable parts only.

---

## M9 — Release Hardening: Artifact Signing + Perimeter (WAF/API GW)
**Goal:** Production release controls (integrity and shielding layers).

- **Deliverables**
  - Sigstore/Cosign signing for container images; SBOM attached.
  - WAF/API Gateway fronting Gatekeeper; virtual patching capability.
  - Release gates: control-plane must be clean; realm findings allowed by policy.

- **US**
  - As an operator, I can verify image authenticity and block common attacks at the edge.

- **AbS**
  - As an attacker, I push a tampered image; signature verification blocks rollout.

- **AC**
  - `cosign verify` passes in CI; deployment rejects unsigned images.
  - WAF tuned with allowlist-based routing to Gatekeeper only.

- **ASVS**
  - V16 (DevSecOps), V9 (TLS), V14 (config).

- **DoD**
  - Release checklist signed; artifacts archived; rollback tested.

---

## M10 — Comprehensive README & Developer Experience
**Goal:** World-class onboarding and operations guide.

- **Deliverables**
  - Comprehensive `README.md` covering: setup, `make` targets, local dev, env vars, DAST staging, contribution, troubleshooting.
  - Short videos or asciinema snippets (optional).

- **US**
  - As a new contributor, I can run the stack in minutes.

- **AbS**
  - As an attacker, I rely on poor docs to cause misconfig; mitigated by explicit guardrails.

- **AC**
  - New laptop dry-run completes in ≤ 15 minutes using README + Makefile only.

- **ASVS**
  - V1/V16 (documentation and DevSecOps).

- **DoD**
  - Docs peer-reviewed; green badge in CI for docs link checks (optional).

---

## Cross-cutting S‑SDLC Activities at Every Milestone
- **Requirements**: Update ASVS mapping to reflect scope changes; tag “N/A-intentional” where applicable for realms.
- **Design**: Update DFD + threat model if a new trust boundary or data store is added.
- **Coding**: Pre-commit + SAST/SCA clean; secrets only via env/secret manager.
- **Testing**: Unit/integration tests; DAST in staging (control-plane must remain clean).
- **Release**: Signed artifacts (post M9), evidence archived.
- **Maintenance**: Update runbook; rotate keys periodically; patch base images.

---

## Definition of Ready (before starting each milestone)
- User stories and acceptance criteria finalized.
- Security decisions documented in `.docs/` (ADR if needed).
- Test plan (unit/e2e/DAST) written and linked to ASVS items.

## Definition of Done (for each milestone)
- All ACs met; tests green locally and in CI.
- Updated documentation committed under `.docs/`.
- Security gates passed (SAST/SCA/Secret/DAST control-plane clean).
- Risks logged (if any) with mitigation or acceptance.