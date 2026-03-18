#!/bin/sh
set -eu

identity=""
if [ "${1:-}" = "-i" ]; then
  identity="$2"
  shift 2
fi

dir="${1:-.}"

expected_fp=$(mktemp)
actual_fp=$(mktemp)
plain_secret=$(umask 077 && mktemp)
trap 'rm -f "$expected_fp" "$actual_fp" "$plain_secret"' EXIT

for age_file in "$dir"/*.age; do
  [ -f "$age_file" ] || continue
  recipients_file="${age_file}.recipients.txt"

  # Detect armored format
  is_armored=false
  case "$(head -n1 "$age_file")" in
  "-----BEGIN AGE ENCRYPTED FILE-----") is_armored=true ;;
  esac

  # Compute expected fingerprints from recipients file
  # fingerprint = base64_no_padding(first_4_bytes(sha256(base64_decode(field2))))
  while IFS= read -r pubkey_line; do
    hex=$(echo "$pubkey_line" | cut -d' ' -f2 | base64 -d | sha256sum | head -c 8)
    # shellcheck disable=SC2001
    printf '%b' "$(echo "$hex" | sed 's/../\\x&/g')" | base64 | tr -d '='
  done <"$recipients_file" | sort >"$expected_fp"

  # Extract actual fingerprints from age file header
  age_binary=$(cat "$age_file")
  if [ "$is_armored" = true ]; then
    age_binary=$(echo "$age_binary" | sed '1d;$d' | base64 -d)
  fi
  echo "$age_binary" | sed -n 's/^-> ssh-ed25519 \([^ ]*\).*/\1/p' | sort >"$actual_fp"

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
done
