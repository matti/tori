#!/usr/bin/env bash
set -Euo pipefail

CONTAINER_INDEX=""
while true; do
  CONTAINER_INDEX=$(curl -f --max-time 1 -s --unix-socket /run/docker.sock http://docker/containers/$HOSTNAME/json | jq -r '.Name' | cut -d'_' -f3) || true
  [[ "$CONTAINER_INDEX" != "" ]] && break
  sleep 1
done
export CONTAINER_INDEX


cat /app/torrc.template | sed -e "s/__CONTAINER_INDEX__/${CONTAINER_INDEX}/" > /tmp/torrc
cat /app/nftables.template | sed -e "s/__CONTAINER_INDEX__/${CONTAINER_INDEX}/" > /tmp/nftables

echo """
nameserver 127.0.0.1
""" > /etc/resolv.conf

(
  _term() {
    echo "RESTART!"
  }
  trap _term TERM

  while true; do
    tor -f /tmp/torrc &
    tor_pid=$!
    wait || true

    kill $tor_pid || true
    wait $tor_pid || true

    echo "TOR EXITED"
    sleep 0.1
  done
) >/tmp/tor.stdout 2>/tmp/tor.stderr &
echo "$!" > /tmp/tor.pid

(
  cd /tmp
  exec tailer tor.stdout tor.stderr
) &

(
  failures=0
  while true; do
    start=$SECONDS

    if printf "AUTHENTICATE\nGETINFO network-liveness\nQUIT\n" | nc localhost 9051 | grep -q "network-liveness=up" && nslookup -port=53 google.com localhost | grep -v NXDOMAIN | grep -q google; then
      failures=0
    else
      echo "failures: $failures"
      failures=$((failures + 1))

      if [[ "$failures" -gt 15 ]]; then
        failures=0
        kill "$(cat /tmp/tor.pid)"
      fi
    fi

    took=$((SECONDS - start))
    if [[ "$took" < 1 ]]; then
      sleep 1
    fi
  done
) &

(
  while true; do
    start=$SECONDS
    isTor=$(curl -Lfs --max-time 5 --socks5 127.0.0.1:9050 --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip | jq -r '.IsTor') || true

    [[ "$isTor" == "true" ]] && break

    took=$((SECONDS - start))
    if [[ "$took" < 1 ]]; then
      sleep 1
    fi
  done

  echo ""
  echo "tor ok"
)

nft -f /tmp/nftables

(
  lastip=""
  while true; do
    if ip=$(curl -sf ip.jes.fi); then
      :
    else
      echo "failed"
    fi

    sleep 1
  done
)
echo "hang"
tail -f /dev/null
