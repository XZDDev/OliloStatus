# Reverse proxy (Cloudflare-fronted)

Nginx sits in front of the notifications backend. The site runs behind Cloudflare
(proxied / orange-cloud) on the domain you set in `PROXY_DOMAIN` (default
`notifications.example.com`), with TLS terminated at the origin by a **Cloudflare
Origin Certificate** and locked down with **Authenticated Origin Pulls** so only
Cloudflare can reach the origin.

```
client --TLS--> Cloudflare --TLS (Origin Cert + mTLS)--> nginx :443 --> app :3000
```

The app container is no longer published to the host - only nginx is exposed
(ports 80/443), and it proxies to `app:3000` over the compose network.

## What "protection" this gives

- **Origin Certificate** encrypts the Cloudflare-to-origin hop (set Cloudflare
  SSL/TLS mode to **Full (strict)**).
- **Authenticated Origin Pulls (mTLS)** - nginx requires Cloudflare's client
  certificate, so anyone hitting the origin IP directly (bypassing Cloudflare and
  its WAF/rate limits) is rejected at the TLS handshake.
- **Real visitor IPs** restored from `CF-Connecting-IP` (trusted only from
  Cloudflare ranges in `cloudflare-ips.conf`), so logs and rate limiting are per
  real client.
- **Rate limiting** (20 r/s/IP, burst 40) and a small request-body cap.

## One-time setup

Set your domain in `.env` (it's injected into the nginx config at start):

```sh
PROXY_DOMAIN=status-notify.yourdomain.tld
```

The cert/CA files below go under `proxy/` and are git-ignored (except `.gitkeep`).

### 1. Cloudflare Origin Certificate

Cloudflare dashboard -> SSL/TLS -> Origin Server -> **Create Certificate**
(hostnames: `notifications.example.com`). Save the two PEM blocks:

```
proxy/certs/origin.crt   # the certificate
proxy/certs/origin.key   # the private key  (keep secret)
```

Then set SSL/TLS encryption mode to **Full (strict)**.

### 2. Authenticated Origin Pulls

Enable it in Cloudflare (SSL/TLS -> Origin Server -> *Authenticated Origin
Pulls*, zone-level), then put Cloudflare's pull CA on the origin:

```sh
curl -fsSL https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem \
  -o proxy/cf/authenticated_origin_pull_ca.pem
```

> To disable mTLS temporarily (e.g. first boot before it's configured), comment
> out the `ssl_client_certificate` / `ssl_verify_client` lines in
> `default.conf.template`.

### 3. DNS

Add an `A`/`AAAA` record for `notifications.example.com` pointing at the origin
host, **proxied (orange cloud)**. Open ports 80/443 to Cloudflare only (ideally
firewall the origin to Cloudflare IP ranges as well).

### 4. Run

```sh
docker compose --profile proxy up -d --build
```

Check it:

```sh
# Through Cloudflare (works):
curl https://notifications.example.com/health

# Direct to origin without Cloudflare's client cert (should be refused by mTLS):
curl --resolve notifications.example.com:443:<ORIGIN_IP> https://notifications.example.com/health
```

## Files

| File | Purpose |
| --- | --- |
| `default.conf.template` | nginx server config (TLS, mTLS, rate limit, proxy); `${PROXY_DOMAIN}` filled at start |
| `cloudflare-ips.conf` | Cloudflare IP ranges trusted for `CF-Connecting-IP` |
| `certs/origin.crt`, `certs/origin.key` | Cloudflare Origin Certificate (you provide) |
| `cf/authenticated_origin_pull_ca.pem` | Cloudflare pull CA (you fetch, step 2) |

## Notes

- The device API still uses its own `API_KEY` (`x-api-key`) on top of all this -
  the proxy doesn't replace it.
- Cloudflare IP ranges rarely change; refresh `cloudflare-ips.conf` from
  <https://www.cloudflare.com/ips/> if needed.
