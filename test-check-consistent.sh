#!/bin/sh
# shellcheck disable=SC2154
# Test: --check returns 0 when recipients.txt matches age file

# Generate recipient keys
mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q

# Create recipients file with actual keys
cat keys/alice.pub keys/bob.pub >secret.age.recipients.txt

# Create test file and encrypt with recipients
echo "secret data" >plain.txt
age -e -R secret.age.recipients.txt -o secret.age plain.txt

# Run check - should succeed
age-rekey secret.age

echo "PASS: test-check-consistent"
touch "$out"
