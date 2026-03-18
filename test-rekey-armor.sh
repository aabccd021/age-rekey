#!/bin/sh
# shellcheck disable=SC2154
# Test: Preserves armor format when rekeying

# Generate recipient keys
mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q

# Create test file and encrypt with armor (-a) and only alice
echo "secret data" >plain.txt
age -e -a -R keys/alice.pub -o secret.age plain.txt

# Verify it's armored
if ! head -n1 secret.age | grep -q '^-----BEGIN AGE ENCRYPTED FILE-----$'; then
  echo "FAIL: Initial file should be armored" >&2
  exit 1
fi

# Create recipients file with both alice and bob
cat keys/alice.pub keys/bob.pub >secret.age.recipients.txt

# Run rekey
age-rekey -i keys/alice

# Verify output is still armored
if ! head -n1 secret.age | grep -q '^-----BEGIN AGE ENCRYPTED FILE-----$'; then
  echo "FAIL: Rekeyed file should preserve armor format" >&2
  exit 1
fi

# Verify bob can decrypt
decrypted=$(age -d -i keys/bob secret.age)
if [ "$decrypted" != "secret data" ]; then
  echo "FAIL: Bob could not decrypt after rekey" >&2
  exit 1
fi

echo "PASS: test-rekey-armor"
touch "$out"
