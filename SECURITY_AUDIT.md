# Security Audit & Improvement Plan

## Findings

### Priority 1: 🔴 Critical
1. **Credential Storage on Disk** — Tokens stored in plaintext JSON file (`~/.foxyvpn-desktop-token.json`). Should use Windows Credential Manager on Windows (as README states for Stage 4 but not yet implemented).
2. **No TLS verification override in HTTP clients** — The `http.Client` instances don't configure TLS explicitly, relying on defaults. Should pin or verify Mozilla/Fastly certificates.

### Priority 2: 🟠 High
3. **XSS Risk in UI** — The web UI injects `error` messages into DOM via `alert()` without sanitization. Could be exploited if server returns malicious error text.
4. **No CSRF protection** — The local web server has no CSRF tokens. A malicious webpage could trigger API calls.
5. **Open redirect via `route add`** — The `addRoutes` function passes hostname to `route add` without validation (command injection risk if hostname contains shell metachar characters).

### Priority 3: 🟡 Medium
6. **Missing Content-Security-Policy** — HTML responses have no CSP headers.
7. **No rate limiting** — Login endpoint (`/api/login`) accepts unlimited attempts (brute-force risk).
8. **Token exposure in logs** — Some error paths may log bearer tokens or refresh tokens.
9. **No upgrade security** — The binary download URL isn't verified (no checksum/signature check).

### Priority 4: 🟢 Low
10. **Static HTML served without cache headers** — Could be cached by browser.
11. **No HTTPS for local UI** — All traffic is HTTP on localhost (mitigated by localhost-only binding).

## Improvements To Implement (in priority order)

### Tier 1: Security hardening
- [ ] Implement Windows Credential Manager token storage
- [ ] Add CSRF protection for local API
- [ ] Sanitize all DOM injection in UI
- [ ] Add Content-Security-Policy header
- [ ] Add rate limiting to auth endpoints

### Tier 2: Build & distribution
- [ ] Add Windows binary builds to CI (GOOS=windows)
- [ ] Add GitHub Releases auto-publish workflow
- [ ] Add binary signing (optional)

### Tier 3: Testing
- [ ] Integration test for SOCKS5 proxy
- [ ] Integration test for HTTP proxy
- [ ] Integration test for auth flow (mocked backend)