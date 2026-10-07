# Password login and the Login keyring

The desktop starts after a password login on tty1, using the existing Fish
`exec niri-session` path. Autologin and empty login passwords are disabled. PAM
passes the account password to GNOME Keyring.

Howdy is a **required additional factor** for `sudo` and `swaylock` only. Login,
SSH, `su`, and polkit do not depend on the camera. Face recognition is not a
replacement for a password. The polkit helper keeps its upstream device sandbox.

## Before activating

1. Verify you know the current account password. `passwd -S "$USER"` should
   report `P`, not `NP` or `L`. Use `passwd` interactively if needed.
2. With the current generation, verify enrollment: `sudo howdy test`. Enroll with
   `sudo howdy add` if needed; check the camera at `/dev/video2` and configure the
   IR emitter if required. Do not activate required-face authentication with an
   untested camera.
3. Keep a root recovery shell open while testing PAM: `sudo -i`.
4. Build first, then use `sudo nixos-rebuild test --flake .#nixos`. Test a fresh
   password login on another VT, `sudo -k; sudo true`, and screen unlock before
   making the generation persistent. Changes to getty may end the tty1 session;
   save work and test from another VT or SSH.

## Set a non-empty keyring password

This is private, mutable user data, not a Nix option. No root privilege is needed
for your own keyring, but the interactive password prompt must be handled by you.
Do not paste your password into chat or put it in command arguments.

1. Open **Passwords and Keys** (`seahorse`).
2. In **Passwords**, right-click the **Login** keyring and choose **Change
   Password**. If its current password is empty, leave the old-password field
   blank. If it is already protected, enter its current password.
3. Set the new password to your **non-empty account login password**. Do not
   delete/recreate the keyring: that would discard stored secrets. Ensure Login
   is the default password keyring if applications used a different one.
4. After activating password login, log out completely (or reboot), then sign in
   with the account password. The Login keyring should unlock through PAM without
   a separate prompt. A mismatching keyring password requires manual unlocking.

Changing the configuration does not itself re-encrypt an existing empty-password
keyring. Complete these steps to protect its stored contents at rest.

## Recovery and limitations

If face authentication fails, tty login still accepts the account password. Use
a password-based polkit prompt or the root shell kept open during testing to
restore the previous generation; boot the prior generation if necessary. Do not
remove the password requirement to work around a camera issue.

Disk encryption is intentionally unchanged. A protected keyring does not encrypt
other files on the laptop, and local snapshots are not off-device backups.
