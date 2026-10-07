# Renew on the host with a systemd timer

The server that terminates TLS runs the KrakenKey CLI itself: it creates its own private key, gets the certificate, and a daily timer renews it and reloads nginx or HAProxy. The key never leaves the machine, and the server needs no DNS credentials and no inbound port 80. The [nginx and HAProxy guide](https://krakenkey.io/docs/integrations/nginx-haproxy/) explains each step.

| File | Install to |
|------|------------|
| [`krakenkey-renew`](krakenkey-renew) | `/usr/local/bin/krakenkey-renew` (mode 0755) |
| [`renew.env.example`](renew.env.example) | `/etc/krakenkey/renew.env`, edited for your names |
| [`systemd/krakenkey-renew.service`](systemd/krakenkey-renew.service) | `/etc/systemd/system/` |
| [`systemd/krakenkey-renew.timer`](systemd/krakenkey-renew.timer) | `/etc/systemd/system/` |
| [`nginx/example.com.conf`](nginx/example.com.conf) | your nginx config, for example `/etc/nginx/conf.d/` |

## Set up

Needs the [KrakenKey CLI](https://krakenkey.io/docs/cli/) v0.7.0 or later, `openssl` and `jq`. As root:

```bash
# API key, root-only
install -d -m 0755 /etc/krakenkey
( umask 077; echo 'KK_API_KEY=kk_...' > /etc/krakenkey/env )

# Issue once, on this host. Only the CSR leaves the machine.
install -d -m 0700 /etc/ssl/krakenkey
cd /etc/ssl/krakenkey
set -a; . /etc/krakenkey/env; set +a
krakenkey cert issue --domain example.com --san www.example.com \
  --key-out example.com.key --fullchain-out example.com.fullchain.pem --wait
echo <certificate id> > example.com.id
chmod 0600 example.com.key

# Renewal
install -m 0755 krakenkey-renew /usr/local/bin/
install -m 0644 renew.env.example /etc/krakenkey/renew.env   # then edit it
install -m 0644 systemd/krakenkey-renew.{service,timer} /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now krakenkey-renew.timer
systemctl start krakenkey-renew.service && journalctl -u krakenkey-renew -n 5
```

Then point nginx at the files (see [`nginx/example.com.conf`](nginx/example.com.conf)) and run `nginx -t && systemctl reload nginx`. For HAProxy, set `KK_PROXY=haproxy`; the script builds `/etc/haproxy/certs/<name>.pem` from the full chain and key.

## What the script does

1. Checks the certificate's status, and waits for the next run if a renewal is already in progress.
2. Asks KrakenKey to renew with `--if-due`, which only renews inside your plan's renewal window, so running it daily is safe.
3. Downloads the current full chain and installs it only if it expires later than the live one, matches the key on disk, and covers every name in `KK_HOSTS`. That also picks up renewals done by KrakenKey's own auto-renew.
4. Keeps the previous file as `.prev`, then tests the proxy config and reloads.

## Tests

[`test/run.sh`](test/run.sh) runs the script against a fake `krakenkey` CLI and a throwaway CA, with no network or account: an up-to-date certificate, a newer one, one with the wrong key, one missing a name, a renewal in progress, and a failed certificate. CI runs it with shellcheck and `systemd-analyze verify`.
