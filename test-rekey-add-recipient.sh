#!/bin/sh
# shellcheck disable=SC2154
# Test: Adds a new recipient when recipients.txt has more keys

# Generate recipient keys
mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q

# Create test file and encrypt with only alice
echo "secret data" >plain.txt
age -e -R keys/alice.pub -o secret.age plain.txt

# Create recipients file with both alice and bob
cat keys/alice.pub keys/bob.pub >secret.age.recipients.txt

# Run rekey (not check mode) - use alice's private key to decrypt
age-rekey -i keys/alice

# Verify bob can now decrypt
decrypted=$(age -d -i keys/bob secret.age)
if [ "$decrypted" != "secret data" ]; then
  echo "FAIL: Bob could not decrypt after rekey" >&2
  exit 1
fi

# Verify alice can still decrypt
decrypted=$(age -d -i keys/alice secret.age)
if [ "$decrypted" != "secret data" ]; then
  echo "FAIL: Alice could not decrypt after rekey" >&2
  exit 1
fi

# Verify check now passes
age-rekey

echo "PASS: test-rekey-add-recipient"
touch "$out"
