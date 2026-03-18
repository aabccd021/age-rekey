#!/bin/sh
# shellcheck disable=SC2154
# Test: --check fails when same count but different keys

mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q
ssh-keygen -t ed25519 -f keys/charlie -N "" -q

echo "secret data" >plain.txt
cat keys/alice.pub keys/bob.pub >encrypt.txt
age -e -R encrypt.txt -o secret.age plain.txt

cat keys/alice.pub keys/charlie.pub >secret.age.recipients.txt

if age-rekey secret.age; then
  echo "FAIL: Expected non-zero exit code" >&2
  exit 1
fi

echo "PASS: test-check-different-key"
touch "$out"
