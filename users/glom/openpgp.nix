{
  # Provision and back up the key first; see docs/yubikey.md.
  # SOPS selects the encryption subkey from this public identity.
  primaryFingerprint = "AE7977EF0356263C91F34C5D99A8A2212CBE37ED";

  # Use the FULL signing-subkey fingerprint followed by !, not the primary
  # fingerprint or email. The ! prevents GnuPG from choosing another subkey.
  signingKey = "AF48DC862D8E359C5AABFAF36DCFBF390C116EF3!";

  # Set to ./keys/openpgp.asc after exporting your PUBLIC certificate there.
  # Never put private keys, revocation certificates, or PINs in this repository.
  publicKeyFile = ./keys/openpgp.asc;
}
