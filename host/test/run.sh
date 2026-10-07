#!/usr/bin/env bash
# Tests for host/krakenkey-renew against a fake krakenkey CLI and a throwaway
# CA. No network, no KrakenKey account, no root. Run from the repository root:
#   bash host/test/run.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cd "$T"

# --- certificates -------------------------------------------------------
mkdir -p ca bin
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -subj /CN=Test-CA \
  -keyout ca/ca.key -out ca/ca.pem -days 365 2>/dev/null
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out server.key 2>/dev/null
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out other.key 2>/dev/null

# leaf <name> <key> <days> <dns names...>: writes <name>.pem as leaf + CA.
leaf() {
  local name=$1 key=$2 days=$3; shift 3
  local san; san=$(printf 'DNS:%s,' "$@"); san=${san%,}
  openssl req -new -key "$key" -subj "/CN=$1" -addext "subjectAltName=$san" -out "$name.csr" 2>/dev/null
  openssl x509 -req -in "$name.csr" -CA ca/ca.pem -CAkey ca/ca.key -CAcreateserial \
    -days "$days" -copy_extensions copy -out "$name.leaf" 2>/dev/null
  cat "$name.leaf" ca/ca.pem > "$name.pem"
}
leaf current server.key 30 example.com www.example.com
leaf newer server.key 90 example.com www.example.com
leaf otherkey other.key 90 example.com www.example.com
leaf missingname server.key 90 example.com

# --- fake krakenkey CLI -------------------------------------------------
cat > bin/krakenkey <<'SHIM'
#!/usr/bin/env bash
# Behaves like the parts of the CLI the script uses. FAKE_STATUS and
# FAKE_DOWNLOAD choose the answers; every call is logged to $FAKE_LOG.
echo "$*" >> "$FAKE_LOG"
case "$1 $2" in
  "cert show") printf '{"id":%s,"status":"%s"}\n' "$3" "$FAKE_STATUS" ;;
  "cert renew") ;;
  "cert download")
    while [ $# -gt 0 ]; do [ "$1" = --out ] && cp "$FAKE_DOWNLOAD" "$2"; shift; done ;;
  *) echo "unexpected: $*" >&2; exit 2 ;;
esac
SHIM
chmod +x bin/krakenkey

# --- harness ------------------------------------------------------------
pass=0 fail=0
# run <description> <status> <download> <expected exit> <expected leaf after> <expected log text>
run() {
  local desc=$1 status=$2 download=$3 want_rc=$4 want_leaf=$5 want_text=$6
  rm -rf live && mkdir live
  cp server.key live/example.com.key
  cp current.pem live/example.com.fullchain.pem
  echo 7 > live/example.com.id
  : > calls.log
  set +e
  out=$(PATH="$T/bin:$PATH" FAKE_LOG="$T/calls.log" FAKE_STATUS=$status FAKE_DOWNLOAD="$T/$download.pem" \
    KK_NAME=example.com KK_HOSTS="example.com www.example.com" KK_PROXY=none KK_DIR="$T/live" \
    "$ROOT/host/krakenkey-renew" 2>&1)
  rc=$?
  set -e
  local got_leaf; got_leaf=$(cmp -s live/example.com.fullchain.pem "$want_leaf.pem" && echo "$want_leaf" || echo other)
  if [ "$rc" = "$want_rc" ] && [ "$got_leaf" = "$want_leaf" ] && grep -q -- "$want_text" <<<"$out" \
     && ! compgen -G "live/.work.*" >/dev/null; then
    echo "ok   - $desc"; pass=$((pass + 1))
  else
    echo "FAIL - $desc (exit $rc, want $want_rc; installed $got_leaf, want $want_leaf)"; printf '       %s\n' "${out//$'\n'/$'\n'       }"
    fail=$((fail + 1))
  fi
}

run "same certificate: nothing installed"           issued   current     0 current "up to date"
run "newer certificate: installed"                   issued   newer       0 newer   "installed certificate"
run "different key: refused"                         issued   otherkey    1 current "doesn't match the key"
run "missing a name: refused"                        issued   missingname 1 current "doesn't cover www.example.com"
run "renewal in progress: left alone"                renewing newer       0 current "trying again next run"
run "failed certificate: run fails"                  failed   newer       1 current "is failed"

# The newer-certificate case keeps the previous file next to the live one.
run "newer certificate: previous kept" issued newer 0 newer "installed certificate"
if cmp -s live/example.com.fullchain.pem.prev current.pem; then echo "ok   - previous certificate saved as .prev"; pass=$((pass + 1)); else echo "FAIL - .prev missing"; fail=$((fail + 1)); fi
# A renewal in progress must not call renew or download.
run "renewing: no renew call" renewing newer 0 current "trying again"
if ! grep -q "cert renew" calls.log; then echo "ok   - no renew while renewing"; pass=$((pass + 1)); else echo "FAIL - renew called while renewing"; fail=$((fail + 1)); fi
# Due checks happen on the server: the script always passes --if-due.
run "issued: renew uses --if-due" issued current 0 current "up to date"
if grep -q -- "cert renew 7 --if-due" calls.log; then echo "ok   - renew passes --if-due"; pass=$((pass + 1)); else echo "FAIL - renew without --if-due"; cat calls.log; fail=$((fail + 1)); fi

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
