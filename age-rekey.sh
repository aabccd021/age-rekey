#!/bin/sh
set -eu

identity=""
if [ "${1:-}" = "-i" ]; then
  identity="$2"
  shift 2
fi

dir="${1:-.}"

# Collect all .age files from directory
age_files=$(mktemp)
for f in "$dir"/*.age; do
  [ -f "$f" ] && echo "$f" >>"$age_files"
done

if [ ! -s "$age_files" ]; then
  echo "No .age files found in $dir" >&2
  rm -f "$age_files"
  exit 1
fi

expected_fp=$(mktemp)
actual_fp=$(mktemp)
plain_secret=$(umask 077 && mktemp)
trap 'rm -f "$age_files" "$expected_fp" "$actual_fp" "$plain_secret"' EXIT

while IFS= read -r age_file; do
  recipients_file="${age_file}.recipients.txt"

  # Detect armored format
  is_armored=false
  if head -n1 "$age_file" | grep -q '^-----BEGIN AGE ENCRYPTED FILE-----$'; then
    is_armored=true
  fi

  # Compute expected fingerprints from recipients file
  # fingerprint = base64_no_padding(first_4_bytes(sha256(base64_decode(field2))))
  while IFS= read -r pubkey_line; do
    echo "$pubkey_line" | cut -d' ' -f2 | base64 -d | sha256sum | head -c 8 | xxd -r -p | base64 | tr -d '='
  done <"$recipients_file" | sort >"$expected_fp"

  # Extract actual fingerprints from age file header
  age_binary=$(cat "$age_file")
  if [ "$is_armored" = true ]; then
    age_binary=$(echo "$age_binary" | sed '1d;$d' | base64 -d)
  fi
  echo "$age_binary" | grep -ao '^-> ssh-ed25519 [^ ]*' | cut -d' ' -f3 | sort >"$actual_fp"

  if diff -q "$expected_fp" "$actual_fp" >/dev/null; then
    echo "OK: $age_file" >&2
    continue
  fi

  # No identity provided = check mode, exit on mismatch
  if [ -z "$identity" ]; then
    echo "MISMATCH: $age_file" >&2
    exit 1
  fi

  # Rekey: decrypt and re-encrypt with new recipients
  echo "Rekeying: $age_file" >&2

  age -d -i "$identity" "$age_file" >"$plain_secret"

  armor_flag=""
  if [ "$is_armored" = true ]; then
    armor_flag="-a"
  fi
  age -e $armor_flag -R "$recipients_file" -o "$age_file" "$plain_secret"
done <"$age_files"
