# Kademos Yggdrasil — Control-Plane Hardening Checklist (Gatekeeper, Flag-Oracle, Redis)

**Scope:** This checklist applies to the *control plane* only: `core/gatekeeper`, `core/flag-oracle`, and their persistence (Redis). Realms remain intentionally vulnerable for training and benchmarking.

## Architectural Principles
- Zero Trust between services: every internal call is authenticated and authorized.
- Single ingress: only `gatekeeper` is exposed publicly.
- Strong isolation: realms cannot reach control-plane networks directly.
- Secrets never live in images or source; they’re injected at deploy time via secret stores or CI/CD.

---

## A. Authentication & Authorization
- [ ] Gatekeeper admin routes protected by MFA-capable IdP (OIDC/OAuth2) or TOTP + strong password.
- [ ] Inter-service calls use **signed service tokens** (short-lived JWT or mTLS client certs).
- [ ] Flag-Oracle enforces authz: only Gatekeeper’s principal can call `POST /validate`, `POST /progress`.
- [ ] Session cookies (if used): `Secure`, `HttpOnly`, `SameSite=Lax` or `Strict`, rotation on privilege change.
- [ ] Admin APIs bound to private interface and IP allowlist (CI jumpbox only).

### Example (Node.js/Express — Gatekeeper admin guard)
```js
// middleware/adminAuth.js
import jwt from "jsonwebtoken";
export function requireServiceToken(req, res, next) {
  const hdr = req.headers["authorization"] || "";
  const token = hdr.startsWith("Bearer ") ? hdr.slice(7) : null;
  if (!token) return res.status(401).send("missing token");
  try {
    const claims = jwt.verify(token, process.env.SERVICE_JWT_PUBLIC_KEY, { algorithms: ["RS256"], clockTolerance: 5 });
    if (claims.aud !== "flag-oracle" || claims.iss !== "gatekeeper") return res.status(403).send("bad audience/issuer");
    req.service = claims.sub;
    return next();
  } catch (e) {
    return res.status(401).send("invalid token");
  }
}
```

---

## B. mTLS for Service-to-Service Calls (Optional or in addition to JWT)
- [ ] Issue per-service client certificates from an internal CA.
- [ ] Gatekeeper ↔ Flag-Oracle HTTPS with mutual auth; reject unknown CAs, set minimum TLS 1.2/1.3.
- [ ] Pin CA in each service.

### Example (Node.js Axios mTLS call to Flag-Oracle)
```js
import https from "https";
import axios from "axios";
const agent = new https.Agent({
  cert: Buffer.from(process.env.MTLS_CLIENT_CERT, "base64"),
  key: Buffer.from(process.env.MTLS_CLIENT_KEY, "base64"),
  ca: Buffer.from(process.env.MTLS_CA_CERT, "base64"),
  honorCipherOrder: true,
  minVersion: "TLSv1.2",
  rejectUnauthorized: true
});
const oracle = axios.create({ baseURL: process.env.ORACLE_URL, httpsAgent: agent, timeout: 5000 });
```

### Docker Compose snippet (mount client certs as secrets)
```yaml
services:
  gatekeeper:
    image: ygg/gatekeeper:latest
    environment:
      ORACLE_URL: https://flag-oracle:8443
      MTLS_CLIENT_CERT: ${MTLS_CLIENT_CERT_B64}
      MTLS_CLIENT_KEY: ${MTLS_CLIENT_KEY_B64}
      MTLS_CA_CERT: ${MTLS_CA_CERT_B64}
    secrets:
      - mtls_client_cert
      - mtls_client_key
      - mtls_ca_cert
secrets:
  mtls_client_cert:
    file: ./secrets/gatekeeper/client.crt
  mtls_client_key:
    file: ./secrets/gatekeeper/client.key
  mtls_ca_cert:
    file: ./secrets/ca/ca.crt
```

---

## C. Redis Hardening & ACL
- [ ] Bind Redis to a private network only; never expose to host or Internet.
- [ ] Require AUTH; unique username per environment; enable Redis ACL with least privilege.
- [ ] Disable dangerous commands (e.g., `FLUSHALL`, `CONFIG`, `KEYS` in prod) via ACL categories.
- [ ] Use TLS if supported (stunnel or native TLS build); or run within a private network with host firewall rules.

### Example (redis.conf excerpt + ACL file)
```
# redis.conf
bind 0.0.0.0
protected-mode yes
port 6379
requirepass REDACTED # or better, 'user default off' with ACL file
aclfile /usr/local/etc/users.acl
```

```
# users.acl
user default off
user ygg_gatekeeper on +@all ~progress:* >pbkdf2$29000$SALTHEX$HASHHEX
user ygg_flag_oracle on +GET +SET +EXISTS +DEL ~progress:* >pbkdf2$29000$SALTHEX$HASHHEX
```

### Compose (attach only to control-plane net)
```yaml
services:
  redis:
    image: redis:7-alpine
    command: ["redis-server","/usr/local/etc/redis.conf"]
    volumes:
      - ./core/flag-oracle/redis.conf:/usr/local/etc/redis.conf:ro
      - progress_data:/data
    networks: ["control_net"]
networks:
  control_net:
    driver: bridge
volumes:
  progress_data:
```

---

## D. No Secrets in Images or Repos
- [ ] Never bake secrets or flags into Docker images (except intentionally seeded *realm* flags for training).
- [ ] Use build-time args for non-sensitive values only.
- [ ] Pull secrets at runtime from secret store / CI environment; mask in logs.
- [ ] Prevent accidental commits: enable pre-commit hooks (e.g., gitleaks).

### GitHub Actions (secret scanning + prevention)
```yaml
name: secret-scan
on: [pull_request]
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: gitleaks/gitleaks-action@v2
```

---

## E. Network Segmentation & Policies
- [ ] Gatekeeper is the only multi-homed service bridging all realm networks.
- [ ] Flag-Oracle and Redis live **only** on the control network.
- [ ] Host firewall denies realm subnets from reaching control-plane subnet.

---

## F. DAST_MODE Safety
- [ ] `DAST_MODE=false` by default; refuse to enable unless `ENV=staging`.
- [ ] When true, enable rate-limits and set “audit session id” headers for scanner traffic.
- [ ] Ensure admin endpoints remain private in DAST_MODE.

```js
// gatekeeper/startup.js
if (process.env.DAST_MODE === "true" && process.env.ENV !== "staging") {
  throw new Error("Refusing to start in DAST_MODE outside staging");
}
```