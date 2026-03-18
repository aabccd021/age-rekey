#!/bin/sh
set -eu

check_mode=false
identity=""

while [ $# -gt 0 ]; do
  case "$1" in
  --check)
    check_mode=true
    shift
    ;;
  -i)
    identity="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  -*)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  *)
    break
    ;;
  esac
done

if [ $# -eq 0 ]; then
  echo "Usage: age-rekey [--check] [-i identity] <file.age>..." >&2
  exit 1
fi

for age_file in "$@"; do
  recipients_file="${age_file}.recipients.txt"

  if [ ! -f "$recipients_file" ]; then
    echo "Error: Recipients file not found: $recipients_file" >&2
    exit 1
  fi

  is_armored=false
  if head -n1 "$age_file" | grep -q '^-----BEGIN AGE ENCRYPTED FILE-----$'; then
    is_armored=true
  fi

  expected_fp=$(mktemp)
  actual_fp=$(mktemp)
  trap 'rm -f "$expected_fp" "$actual_fp"' EXIT

  while IFS= read -r pubkey_line; do
    echo "$pubkey_line" | cut -d' ' -f2 | base64 -d | sha256sum | head -c 8 | xxd -r -p | base64 | tr -d '='
  done <"$recipients_file" | sort >"$expected_fp"

  age_binary=$(cat "$age_file")
  if [ "$is_armored" = true ]; then
    age_binary=$(echo "$age_binary" | sed '1d;$d' | base64 -d)
  fi
  echo "$age_binary" | grep -ao '^-> ssh-ed25519 [^ ]*' | cut -d' ' -f3 | sort >"$actual_fp"

  if diff -q "$expected_fp" "$actual_fp" >/dev/null; then
    echo "OK: $age_file"
    rm -f "$expected_fp" "$actual_fp"
    continue
  fi

  if [ "$check_mode" = true ]; then
    echo "MISMATCH: $age_file" >&2
    echo "  Expected: $(tr '\n' ' ' <"$expected_fp")" >&2
    echo "  Actual:   $(tr '\n' ' ' <"$actual_fp")" >&2
    exit 1
  fi

  echo "Rekeying: $age_file"

  tmpfile=$(umask 077 && mktemp)
  trap 'rm -f "$expected_fp" "$actual_fp" "$tmpfile"' EXIT

  age -d -i "$identity" "$age_file" >"$tmpfile"

  armor_flag=""
  if [ "$is_armored" = true ]; then
    armor_flag="-a"
  fi
  age -e $armor_flag -R "$recipients_file" -o "$age_file" "$tmpfile"

  rm -f "$expected_fp" "$actual_fp" "$tmpfile"
done
