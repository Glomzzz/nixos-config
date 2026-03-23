# Package ownership rubric

- Keep packages in NixOS only when they are required for boot, drivers, root/admin workflows, system integration, or NixOS service dependencies.
- Move user-facing CLI, GUI, development, gaming, Wine, and document utility packages to Home Manager unless they are explicitly required by a system service or hardware stack.

## Applied decisions in this task

- Kept `wget`, `curl`, `sysstat`, `lm_sensors`, `input-remapper`, `libevdev`, and `python313Packages.libevdev` in `modules/nixos/programs/system-tools.nix` because they are system/admin or device-integration tools.
- Moved `git`, `fastfetch`, `thunar`, `nnn`, archive tools, `just`, `ripgrep`, `gnumake`, `fd`, `xclip`, and `nix-alien` to `modules/home/programs/cli-tools.nix` because they are user-facing shell and desktop tools.
- Moved `lsfg-vk` and `lsfg-vk-ui` to `modules/home/programs/gaming-utils.nix` because they are gaming utilities, not system integration.
- Moved Wine packages to `modules/home/programs/gaming-wine.nix` because they are user application runtime tools.
- Moved `vulkan-tools`, `vulkan-validation-layers`, and `vulkan-headers` to `modules/home/programs/dev/graphics-debug.nix` because graphics debugging belongs with developer tooling rather than hardware enablement.
- Moved `poppler_data` to `modules/home/programs/documents.nix` because it is a user document utility package.
- Moved `clamtk` to `modules/home/programs/system-utilities.nix` while leaving the `clamav` NixOS service in place, separating the user GUI from the system service.
- Moved `kdePackages.kwallet-pam` and the KDE PAM toggle into `modules/nixos/core/plasma-auth.nix` because PAM integration is a system authentication concern.
- Left `tailscale` only in NixOS service modules and kept it out of Home Manager packages.
