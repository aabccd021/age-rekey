#!/bin/sh
# shellcheck disable=SC2154
# Test: Removes a recipient when recipients.txt has fewer keys

# Generate recipient keys
mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q

# Create test file and encrypt with both alice and bob
echo "secret data" >plain.txt
cat keys/alice.pub keys/bob.pub >both.txt
age -e -R both.txt -o secret.age plain.txt

# Create recipients file with only alice (bob removed)
cp keys/alice.pub secret.age.recipients.txt

# Run rekey (not check mode) - use alice's private key to decrypt
age-rekey -i keys/alice secret.age

# Verify alice can still decrypt
decrypted=$(age -d -i keys/alice secret.age)
if [ "$decrypted" != "secret data" ]; then
  echo "FAIL: Alice could not decrypt after rekey" >&2
  exit 1
fi

# Verify bob can no longer decrypt
if age -d -i keys/bob secret.age 2>/dev/null; then
  echo "FAIL: Bob should not be able to decrypt after being removed" >&2
  exit 1
fi

# Verify check now passes
age-rekey --check secret.age

echo "PASS: test-rekey-remove-recipient"
touch "$out"
