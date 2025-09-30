# Security Guidelines for Scenic MCP

## Overview

Scenic MCP is designed for **development and testing environments**. It provides powerful control over Scenic GUI applications through a TCP server without authentication.

## Security Model

### Current Security Posture

- ✅ Binds to `localhost` (127.0.0.1) only
- ✅ Not accessible from external networks by default
- ❌ **No authentication mechanism**
- ❌ **No authorization checks**
- ❌ **No encryption** (plain TCP)
- ❌ **Not designed for production use**

## Risk Assessment

### Low Risk (Acceptable for v1.0)

**Development Environment:**
- Single developer on local machine
- Testing and debugging Scenic applications
- AI-assisted development with Claude Code/Desktop
- Automated testing pipelines on trusted infrastructure

### High Risk (Not Recommended)

**Production Environment:**
- Public-facing servers
- Multi-user environments
- Untrusted local users
- Any internet-exposed systems

## Threat Model

### What Scenic MCP Protects Against

1. **External Network Access** - Only binds to localhost
2. **Accidental Exposure** - Clear warnings in documentation

### What Scenic MCP Does NOT Protect Against

1. **Local Privilege Escalation** - Any local process can connect
2. **Malicious Local Users** - No authentication required
3. **Process Injection** - Input is directly passed to Scenic
4. **Data Exfiltration** - Screenshots can be captured by any client
5. **Denial of Service** - No rate limiting or connection limits

## Security Best Practices

### For Development Use

1. **Keep Port Localhost Only**
   ```elixir
   # Already default - do NOT change bind address
   :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
   ```

2. **Use Unique Ports**
   ```elixir
   # Prevent conflicts and aid in identifying services
   config :scenic_mcp,
     port: 9999,  # Use unique port per application
     app_name: "MyApp"
   ```

3. **Monitor Connection Logs**
   ```bash
   # Watch for unexpected connections
   tail -f log/dev.log | grep "ScenicMCP"
   ```

4. **Firewall Configuration**
   ```bash
   # Ensure localhost-only access (typically default)
   # On Linux: iptables -A INPUT -p tcp --dport 9999 -i lo -j ACCEPT
   # On macOS: Built-in firewall typically allows localhost
   ```

5. **Close When Not Needed**
   ```elixir
   # In test environments, stop after use
   Supervisor.stop(ScenicMcp.Supervisor)
   ```

### For CI/CD Environments

1. **Isolate Test Runs**
   ```yaml
   # GitHub Actions / GitLab CI
   - Use unique ports per test job
   - Run in isolated containers
   - Clean up processes after tests
   ```

2. **Network Isolation**
   ```dockerfile
   # Docker: No port exposure needed
   # Don't use -p 9999:9999 in docker run
   ```

3. **Temporary Ports**
   ```elixir
   # In test.exs, use random ports
   config :scenic_mcp, port: 9996 + System.unique_integer([:positive]) rem 100
   ```

## Known Vulnerabilities

### V1.0 Limitations

1. **No Authentication** (Accepted Risk)
   - **Impact:** Any local process can control your Scenic app
   - **Mitigation:** Use only in trusted development environments
   - **Future:** May add optional API key authentication in v2.0

2. **No Encryption** (Accepted Risk)
   - **Impact:** Traffic visible to local process monitors
   - **Mitigation:** Localhost-only binding reduces exposure
   - **Future:** TLS support planned for v2.0

3. **No Rate Limiting** (Accepted Risk)
   - **Impact:** Possible DoS through rapid command flooding
   - **Mitigation:** Development use makes this unlikely
   - **Future:** Connection pooling and rate limits in v2.0

4. **Input Validation** (Partially Mitigated)
   - **Impact:** Malformed JSON or commands could cause crashes
   - **Mitigation:** JSON parsing and basic validation in place
   - **Risk:** Edge cases may exist

## Production Deployment (Not Recommended)

If you **absolutely must** deploy Scenic MCP in production, implement these additional measures:

### 1. Add Authentication Layer

```elixir
# Custom authentication wrapper (not included)
defmodule SecureScenicMcp do
  def authenticate(token) do
    # Implement token-based auth
    expected = System.get_env("SCENIC_MCP_TOKEN")
    Plug.Crypto.secure_compare(token, expected)
  end
end
```

### 2. Use Reverse Proxy

```nginx
# Nginx with client certificate auth
location /scenic-mcp {
  proxy_pass http://127.0.0.1:9999;
  ssl_client_certificate /path/to/ca.crt;
  ssl_verify_client on;
}
```

### 3. SSH Tunneling

```bash
# For remote access, use SSH tunnel instead of exposing port
ssh -L 9999:localhost:9999 user@remote-server
```

### 4. VPN Only Access

- Restrict to VPN network
- Use firewall rules to enforce
- Monitor access logs

### 5. Process Isolation

```elixir
# Run Scenic app with restricted user
# Unix: su -c "iex -S mix" restricted_user
```

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public GitHub issue
2. Email security concerns to: [your-security-email]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you on a fix.

## Security Checklist

Before using Scenic MCP, verify:

- [ ] Running in development/test environment only
- [ ] Using localhost-only binding (default)
- [ ] No port forwarding or public exposure
- [ ] Unique port per application
- [ ] Firewall configured correctly
- [ ] Understanding that anyone with local access can control your app
- [ ] Not storing sensitive data in Scenic app state
- [ ] Not using in multi-tenant environments
- [ ] CI/CD runs are isolated
- [ ] Team members understand security limitations

## Security Roadmap

### Planned for v2.0

- [ ] Optional API key authentication
- [ ] TLS/SSL encryption support
- [ ] Rate limiting and connection throttling
- [ ] Audit logging of all commands
- [ ] IP whitelist/blacklist
- [ ] Session management
- [ ] Command allowlist/blocklist

### Under Consideration

- OAuth2 integration
- Role-based access control
- Command signing/verification
- Encrypted screenshot data
- Security scanning tools

## Disclaimer

**Scenic MCP is provided "as is" without warranty of any kind.** Use at your own risk. The maintainers are not responsible for any security breaches, data loss, or damages resulting from the use of this software.

By using Scenic MCP, you acknowledge:

1. You understand the security limitations
2. You will use it only in appropriate environments
3. You will not hold the maintainers liable for security issues
4. You will implement additional security measures if deploying beyond development use

## References

- [OWASP TCP/IP Security](https://owasp.org/www-community/vulnerabilities/)
- [Erlang Security Best Practices](https://erlang.org/doc/apps/ssl/ssl_protocol.html)
- [Elixir Security Working Group](https://github.com/elixir-lang/elixir/security)

---

**Last Updated:** 2025-01-XX
**Version:** 1.0.0
**Maintainer:** [Your Name/Team]
