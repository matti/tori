#!/usr/bin/env bash
set -Euo pipefail

echo "userpoint"
(
  failed=0
  while true; do
    if ip=$(curl --max-time 10 -Lsf ip.jes.fi); then
      if [[ "$failed" == 1 ]]; then
        echo "recovered"
        failed=0
      fi
    else
      echo "failed"
      failed=1
    fi

    sleep 1
  done
)
echo "hang"
tail -f /dev/null & wait
