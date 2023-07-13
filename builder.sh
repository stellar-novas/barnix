#!/usr/bin/env bash
if [ -e .attrs.sh ]; then source .attrs.sh; fi
source $stdenv/setup

echo "getting $files..."
aria=(
  aria2c
  -j "$parallel"
  --dir "$out"
  --retry-wait=5
  --console-log-level=notice
  --optimize-concurrent-downloads true
  --summary-interval=0
  --remove-control-file true
  --no-conf true
  -i "$files"
)

if [ -f "$SSL_CERT_FILE" ]; then
  aria+=(--ca-certificate="$SSL_CERT_FILE")
  aria+=(--check-certificate "$checkCertificate")
else
  aria+=(--ca-certificate="/dev/null")
  aria+=(--check-certificate false)
fi

"${aria[@]}"

