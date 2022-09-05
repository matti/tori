#!/usr/bin/env bash
set -Euo pipefail

(
  _term() {
    echo "RESTART!"
  }
  trap _term TERM

  while true; do
    runuser -u tor -- tor -f /app/torrc &
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

nft -f /app/nftables


# echo "hang"
# tail -f /dev/null & wait

(
  failures=0
  while true; do
    start=$SECONDS

    if printf "AUTHENTICATE\nGETINFO network-liveness\nQUIT\n" | nc localhost 9051 | grep -q "network-liveness=up"; then
      failures=0
    else
      echo "failures: $failures"
      failures=$((failures + 1))

      if [[ "$failures" -gt 30 ]]; then
        failures=0
        kill "$(cat /tmp/tor.pid)"
      fi
    fi

    took=$((SECONDS - start))
    if [[ "$took" -lt 1 ]]; then
      sleep 1
    fi
  done
) &

(
  while true; do
    start=$SECONDS
    isTor=$(curl -Lfs --max-time 10 --socks5 127.0.0.1:9050 --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip | jq -r '.IsTor') || true

    [[ "$isTor" == "true" ]] && break

    took=$((SECONDS - start))
    if [[ "$took" < 1 ]]; then
      sleep 1
    fi
  done

  echo ""
  echo "tor ok"
)

exec su -s /bin/bash app /app/userpoint.sh
