# Graphical login and the Login keyring

TTY1 shows ReGreet: the desktop wallpaper behind a dark Catppuccin login card,
with a clock, user/session selection, and reboot/power controls. Select **Niri**
and sign in with the account password. ReGreet remembers the last authenticated
user and their session. Autologin and empty login passwords are disabled.

The greeter runs in its own niri compositor as the unprivileged `greeter` user.
After authentication, it exits and greetd starts the packaged `niri-session`
desktop entry. There is no Fish tty1 auto-launch hook. Greetd includes the
`login` PAM stack, which passes the account password to GNOME Keyring. Other VTs
and SSH remain plain password/key-based recovery shells.

For `sudo`, a successful Howdy face match **replaces the password prompt**. If
recognition fails or the camera is unavailable, sudo tries an enrolled YubiKey
touch, then falls back to the account password. Face recognition is less secure
than a password and can be spoofed. YubiKey enrollment is initially empty; see
[yubikey.md](yubikey.md) for enrollment, OpenPGP provisioning, and commit signing.

Screen unlocking with `swaylock` accepts **Howdy OR YubiKey touch OR password**:

- **Face only:** press Enter without typing a password, then look at the camera.
  A successful match unlocks immediately; no password is required.
- **Key only:** press Enter; after Howdy fails/times out, touch the enrolled key
  when it flashes. No account password or FIDO PIN is required.
- **Password:** type the account password and press Enter. Howdy is tried first,
  then the key, then PAM checks the submitted password. A missing camera/key or
  failed hardware match does not veto a valid password. A connected, untouched
  key may delay password fallback; unplug it to skip that attempt. These methods
  run sequentially, not concurrently.
- If all methods fail, the screen stays locked. Empty input only starts hardware
  authentication; it cannot authenticate as an empty password.

Login, SSH, `su`, and polkit do not depend on the camera or YubiKey. The polkit
helper keeps its upstream device sandbox. Face/key unlocking does not unlock a
separately locked GNOME Keyring, since no account password is supplied.

## Before activating

1. Verify you know the current account password. `passwd -S "$USER"` should
   report `P`, not `NP` or `L`. Use `passwd` interactively if needed.
2. With the current generation, verify enrollment: `sudo howdy test`. Enroll with
   `sudo howdy add` if needed; check the camera at `/dev/video2` and configure the
   IR emitter if required. Verify face authentication before relying on it;
   password fallback remains available.
3. Keep a root recovery shell open while testing PAM: `sudo -i`.
4. Build first, then use `sudo nixos-rebuild test --flake .#nixos`. Test a fresh
   password login on another VT and `sudo -k; sudo true`: a face match should
   succeed without typing a password. If a key is enrolled, cover the camera and
   confirm touch succeeds after Howdy fails. Unplug the key and keep the camera
   covered to confirm password fallback. For screen unlock, test Enter with no
   input and a face match, then an enrolled key with the camera covered. With
   camera covered and key unplugged, the correct password must unlock; incorrect
   and empty passwords must keep the screen locked. Test all of these before
   making the generation persistent. Save work and test from another VT or SSH:
   replacing tty1's getty with greetd may end the old desktop
   session. Test ReGreet with an incorrect password (must reject), then a correct
   password (must start Niri and unlock the Login keyring). Log out and verify
   that ReGreet returns; check readability on the laptop panel and any docked
   monitor. Ctrl+Alt+F2 opens a recovery console if the greeter fails.

Configuration regressions run with
`nix build --no-link .#checks.x86_64-linux.login`. The check validates the greeter
compositor's KDL, session discovery, and password/keyring PAM integration;
visual appearance and hardware login still require the interactive tests above.
`nix build --no-link .#checks.x86_64-linux.authentication` checks both generated
sudo/unlock PAM stacks, including all face/key/password OR outcomes, missing
hardware modules, all-failed denial, opt-in scope, and empty-input policy, using
synthetic modules rather than real hardware or credentials.

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

If face authentication fails, sudo and screen unlock try the enrolled key, then
the account password; graphical and tty login still accept the password. If a
greeter or PAM regression prevents access, use a password login on another VT, a password-based polkit
prompt, or the root shell kept open during testing to restore the previous
generation. Boot the prior generation if necessary.

Disk encryption is intentionally unchanged. A protected keyring does not encrypt
other files on the laptop, and local snapshots are not off-device backups.
