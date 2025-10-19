# Kademos Yggdrasil — Secure Coding Handbook (Control Plane & Support Services)

**Scope:** This handbook applies to *production-quality* components: `core/gatekeeper`, `core/flag-oracle`, CI/CD code, shared frontend shells, and any utilities.  
**Out of scope:** *Realms* remain intentionally vulnerable for training/benchmarking; do **not** inherit these insecure patterns into control-plane code.

---

## 0. Security Principles
- **Zero Trust:** No implicit trust between services. Authenticate and authorize every call.
- **Least Privilege:** Grant minimal permissions. Narrow network and data scopes.
- **Defense in Depth:** Layered controls (e.g., JWT + mTLS + network ACLs).
- **Assume Breach:** Design for containment and rapid recovery.
- **Usable Security:** Controls must be developer-friendly and automated.

---

## 1. Languages, Frameworks & Baseline Versions
- Node.js 20 LTS (Gatekeeper, some realms), Express 5+, Helmet for security headers.
- Python 3.11+ (Flag-Oracle alt / tools), Flask/FastAPI with pydantic validation.
- Java 17 LTS (select realms), Spring Boot 3.x (only for realm code; follow secure configs if used elsewhere).
- React 18+ for UI shells, fetch with `fetch` or `axios` hardened clients.

---

## 2. Authentication, Session & Service Identity
- **Service-to-Service:** Prefer **JWT (RS256)** with short TTLs or **mTLS client certs**; validate `iss`, `aud`, `exp`, `nbf`.
- **Admin & Ops UIs:** OIDC/OAuth2 login with MFA; session cookies must set `Secure`, `HttpOnly`, `SameSite=Lax|Strict`, and rotate on privilege change.
- **CSRF:** Required on state-changing browser endpoints (same-site cookie model). For pure API + SPA, use token-in-header + same-site cookies.

**Express example (JWT verification middleware):**
```js
import jwt from "jsonwebtoken";
export function requireJwt(aud) {
  return (req,res,next)=>{
    const hdr = req.headers.authorization||"";
    const token = hdr.startsWith("Bearer ")?hdr.slice(7):null;
    if(!token) return res.status(401).end();
    try {
      const c = jwt.verify(token, process.env.SVC_PUBKEY, {algorithms:["RS256"], clockTolerance:5});
      if(c.aud!==aud || c.iss!=="gatekeeper") return res.status(403).end();
      req.sub = c.sub; next();
    } catch(e){ return res.status(401).end(); }
  };
}
```

---

## 3. Input Validation, Output Encoding & Safe Queries
- **Validation:** Fail closed. Use allowlists for IDs, enums, and hostnames. Avoid dynamic eval/RegExp from user input.
- **Database:** Use **parameterized queries** / ORM binding only—no string concatenation.
- **Output Encoding:** Encode untrusted data in HTML, JS, and attributes; avoid `dangerouslySetInnerHTML` in React.

**Node + pg parameterized query:**
```js
const res = await db.query("SELECT * FROM flags WHERE id = $1 AND owner = $2", [id, userId]);
```

**Python FastAPI pydantic validation:**
```py
from pydantic import BaseModel, constr, HttpUrl
class RealmRequest(BaseModel):
    realm: constr(pattern=r"^(niflheim|helheim|asgard)$")
    callback: HttpUrl
```

---

## 4. Secure Communications
- TLS 1.2+ everywhere; HSTS for public surface; disable TLS renegotiation if applicable.
- **mTLS** for S2S or signed JWTs as above.
- Denylist private CIDRs when proxying **and** maintain an allowlist of realm targets to avoid open-proxy/SSRF risks.

---

## 5. Secrets Management
- No secrets in Git; no flags in control-plane images.
- Load secrets via environment or secret store (e.g., OIDC → cloud secrets). Mask secrets in logs.
- Rotate keys routinely; use distinct keys per environment.

---

## 6. Logging, Error Handling & Privacy
- Structured logs (JSON). Never log secrets, tokens, or PII.
- Use unique **audit-correlation-id** from ingress through services.
- Return generic error messages to clients; log detailed stack traces server-side only.
- Log security events: auth failures, admin access, DAST_MODE enablement.

---

## 7. Dependency & Supply Chain Security
- Pin versions; generate **SBOM** on every build.
- Reject builds with **High/Critical** CVEs in control-plane.
- Verify base images (distroless or slim), scan with Trivy/Grype.
- Enable npm `--ignore-scripts` where feasible and audit transitive deps.

---

## 8. Secure Frontend (React)
- Avoid inline event handlers for untrusted data.
- Use `DOMPurify` only if you must render HTML; prefer plain text.
- Set security headers via gateway (CSP, X-Frame-Options, Referrer-Policy).

---

## 9. Docker & Runtime Hardening
- Run as non-root, set `USER` in Dockerfiles.
- Drop capabilities, read-only FS where possible.
- Separate **control_net** from realm networks; gatekeeper is the only bridge.
- Health checks; resource limits to avoid DoS during scans.

**Dockerfile (Node):**
```Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
USER node
EXPOSE 8080
CMD ["node","server.js"]
```

---

## 10. Code Review & Security Gates
- Two-person review for control-plane changes.
- Block on SAST high severity, secret scanner positives, and container Critical/High CVEs.
- Document deviations with risk acceptance and expiry date.

---

## 11. Testing Guidance
- Unit tests include negative/security cases (authz denied, invalid inputs).
- E2E in staging; when `DAST_MODE=true`, restrict environment and collect audit logs.
- Snapshot tests for headers (CSP, HSTS).

---

## 12. References
- OWASP ASVS 5.0 (mapped in project CSV).
- OWASP Top 10 (for realms context).