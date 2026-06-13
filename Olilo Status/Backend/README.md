# Olilo Status - Notifications Backend

A small Node.js service that delivers push notifications for the Olilo Status
apps. It polls the public Olilo status page, detects changes (new incidents,
status updates, resolutions, scheduled maintenance, and component health
transitions), and pushes alerts to registered iOS and Android devices.

- **iOS** delivery via **APNs** (token / `.p8` auth, HTTP/2).
- **Android** delivery via **Firebase Cloud Messaging (FCM)**.
- **PostgreSQL** stores device tokens, preferences, and seen-incident state.

## How it works

```
status.olilo.co.uk            this service                 devices
  v3/summary.json    --poll-->  diff vs. DB  --targeted-->  APNs  (iOS)
  v3/components.json            (poller.js)     push        FCM   (Android)
```

Every `POLL_INTERVAL_SECONDS` the poller fetches `summary.json` and
`components.json`, compares them with the last-known state in Postgres, and for
each meaningful change fans a notification out to the devices whose preferences
opted in. The first poll against an empty database seeds state silently so a
fresh deploy never blasts a backlog of pre-existing incidents.

## Quick start (Docker)

```sh
cp .env.example .env          # fill in APNs + FCM credentials
mkdir -p secrets              # drop AuthKey.p8 and firebase-service-account.json here
docker compose up --build
```

The app waits for Postgres, runs migrations automatically, and starts polling. By
default it's bound to `127.0.0.1:3000` (local only) - public traffic goes through
the reverse proxy.

## Production (behind Cloudflare)

The stack includes an nginx reverse proxy (served on the domain you set in
`PROXY_DOMAIN`), fronted by Cloudflare. It terminates TLS with a Cloudflare Origin
Certificate and uses Authenticated Origin Pulls (mTLS) so the origin only accepts
Cloudflare traffic. It's an opt-in compose profile:

```sh
# one-time: set PROXY_DOMAIN in .env and drop the Cloudflare origin cert + pull
# CA into proxy/ (see proxy/README.md)
docker compose --profile proxy up -d --build
```

Full setup - origin certificate, Authenticated Origin Pulls, DNS, and hardening -
is in [`proxy/README.md`](proxy/README.md).

## Quick start (local Node)

Requires Node.js 20+ and a reachable PostgreSQL instance.

```sh
npm install
cp .env.example .env          # set DATABASE_URL and credentials
npm run migrate               # optional; the server also migrates on boot
npm run dev                   # auto-reload, or `npm start` for production
```

## Configuration

All configuration is via environment variables - see [`.env.example`](.env.example)
for the full list. Highlights:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | PostgreSQL connection string. |
| `API_KEY` | Shared secret required in the `x-api-key` header on `/api/*`. |
| `STATUS_BASE_URL` | Upstream status page (default `https://status.olilo.co.uk`). |
| `POLL_INTERVAL_SECONDS` | Polling cadence (default `60`). |
| `APNS_*` | APNs key (`.p8`), key ID, team ID, bundle ID, sandbox/production. |
| `FCM_SERVICE_ACCOUNT*` | Firebase service-account JSON (inline or file path). |

You can disable either platform with `APNS_ENABLED=false` / `FCM_ENABLED=false`.

### Getting credentials

- **APNs:** Apple Developer -> Keys -> create an APNs Auth Key (`.p8`). Note the
  Key ID and your Team ID. The topic is the app bundle id (`uk.co.olilo.status`).
  Use the sandbox host (`APNS_PRODUCTION=false`) for development/TestFlight
  builds, production for App Store builds.
- **FCM:** Firebase Console -> Project settings -> Service accounts -> *Generate new
  private key*. Save the JSON to `secrets/firebase-service-account.json`.

## API

All `/api/*` routes require the `x-api-key` header when `API_KEY` is set.

### `POST /api/devices/register`

Register or refresh a device. Re-registering the same token updates preferences
and reactivates it.

```jsonc
{
  "token": "<apns-or-fcm-token>",
  "platform": "ios",            // "ios" | "android"
  "preferences": {
    "incidents": true,
    "maintenance": true,
    "componentAlerts": false,
    "networks": ["Openreach", "CityFibre", "Freedom Fibre"]
  },
  "locale": "en_GB",
  "appVersion": "0.1"
}
```

`preferences` is optional and defaults to incidents + maintenance on, component
alerts off. `networks` filters component-level alerts; an empty list means all
networks.

### `PATCH /api/devices/:token/preferences`

```jsonc
{ "platform": "ios", "preferences": { "componentAlerts": true } }
```

### `DELETE /api/devices/:token`

```jsonc
{ "platform": "ios" }
```

Deactivates the device. Tokens that APNs/FCM report as invalid are pruned
automatically on the next send.

### `POST /api/poll`

Forces an immediate poll. Handy for testing, or to wire up an Instatus webhook
instead of waiting for the interval.

### `GET /health`

Unauthenticated liveness probe -> `{ "status": "ok" }`.

## Notification payloads

Notifications carry a `data` block the apps can use for deep-linking:

```jsonc
{ "type": "incident", "incidentId": "<id>", "url": "<status-page-url>" }
```

`type` is one of `incident`, `maintenance`, or `component`.

## Client integration notes

1. Request notification permission, then obtain the platform token
   (`UNUserNotificationCenter` / `deviceToken` on iOS, FCM token on Android).
2. `POST` it to `/api/devices/register` with the user's preferences.
3. Re-register on token refresh and when preferences change.
4. Handle the `data.type` / `data.url` payload to route the user to the relevant
   incident in-app.

## Project layout

```
src/
  index.js              Express app, graceful shutdown
  config.js             Env parsing + validation
  db/                   Pool, migrations, migration runner
  routes/devices.js     Device registration API
  services/
    statusClient.js     Fetches the upstream status JSON
    poller.js           Diffs polls and emits notification events
    notifier.js         Targets devices by preference and dispatches
  push/
    apns.js             APNs HTTP/2 client (token auth)
    fcm.js              Firebase Cloud Messaging client
  repositories/         Postgres data access
```

## License

Copyright (C) 2026 Aydan Abrahams.

GPL-3.0-or-later, matching the rest of the Olilo Status project.
