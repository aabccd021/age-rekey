#!/bin/sh
# shellcheck disable=SC2154
# Test: Consistent files are not modified during rekey

mkdir keys
ssh-keygen -t ed25519 -f keys/alice -N "" -q
ssh-keygen -t ed25519 -f keys/bob -N "" -q

# Create first file - already consistent
cat keys/alice.pub >first.age.recipients.txt
echo "first secret" >plain1.txt
age -e -R first.age.recipients.txt -o first.age plain1.txt
first_hash=$(sha256sum first.age | cut -d' ' -f1)

# Create second file - needs rekeying (add bob)
cat keys/alice.pub >second.age.recipients.txt
echo "second secret" >plain2.txt
age -e -R second.age.recipients.txt -o second.age plain2.txt

# Now update second's recipients to add bob
cat keys/alice.pub keys/bob.pub >second.age.recipients.txt

# Run rekey on both
age-rekey -i keys/alice

# Verify first file was NOT modified
new_first_hash=$(sha256sum first.age | cut -d' ' -f1)
if [ "$first_hash" != "$new_first_hash" ]; then
  echo "FAIL: first.age was modified but should have been skipped" >&2
  exit 1
fi

# Verify second file was rekeyed (bob can decrypt)
decrypted=$(age -d -i keys/bob second.age)
if [ "$decrypted" != "second secret" ]; then
  echo "FAIL: Bob could not decrypt second.age after rekey" >&2
  exit 1
fi

echo "PASS: test-skip-unchanged"
touch "$out"
