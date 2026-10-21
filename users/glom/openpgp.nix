{
  # Provision and back up the key first; see docs/yubikey.md.
  # Use the FULL signing-subkey fingerprint followed by !, not the primary
  # fingerprint or email. The ! prevents GnuPG from choosing another subkey.
  signingKey = "AF48DC862D8E359C5AABFAF36DCFBF390C116EF3!";

  # Set to ./keys/openpgp.asc after exporting your PUBLIC certificate there.
  # Never put private keys, revocation certificates, or PINs in this repository.
  publicKeyFile = ./keys/openpgp.asc;
}
