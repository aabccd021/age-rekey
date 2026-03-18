#!/bin/sh
# shellcheck disable=SC2154
# Test: --check returns non-zero when recipients differ

# Generate recipient keys
mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q

# Create test file and encrypt with only alice
echo "secret data" >plain.txt
age -e -R keys/alice.pub -o secret.age plain.txt

# Create recipients file with both alice and bob (mismatch)
cat keys/alice.pub keys/bob.pub >secret.age.recipients.txt

# Run check - should fail
if age-rekey --check secret.age; then
  echo "FAIL: Expected non-zero exit code" >&2
  exit 1
fi

echo "PASS: test-check-mismatch"
touch "$out"
