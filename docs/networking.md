# Laptop firewall trust

The NixOS nftables rules no longer treat every private-address network as home.
The streaming/discovery ports previously allowed for WiVRn/Steam/mDNS are limited
to:

- `tailscale0`, with tailnet access policy still administered in Tailscale;
- interfaces currently using the approved home NetworkManager profiles, with
  IPv4 sources in `192.168.50.0/24` or IPv6 link-local sources.

The approved UUIDs are declared in `modules/nixos/core/networking.nix`:

- `77cdd16f-65e8-4dec-80cc-72ceb2b1700b`: home Wi-Fi, `sudo connect-me`;
- `72d3039f-b16e-3e34-8f8c-450eea674357`: `Wired connection 1`, the home adapter.

These are profile approvals, **not network authentication**. A wired profile can
follow the adapter elsewhere, and another network can use the same subnet. Use
an unapproved profile outside home; remove the wired approval if that adapter
travels. No broad RFC1918, CGNAT-source, or ULA-source exception remains. IPv6
ULA/global LAN service access is deliberately not assumed without a known prefix.

A NetworkManager dispatcher reconciles the `home-lan-interfaces` set and removes
an interface before normal disconnect. A boot service, post-firewall-reload
reconciliation, and minute timer repair missed events. Reconciliation serializes
updates and changes only this set in an atomic nftables transaction. A failed
NetworkManager query empties it. A new ruleset always starts with an empty set;
it never embeds a previously active interface as permanent trust.

This configuration does not run `nmcli connection modify` or change Wi-Fi
credentials. An already-connected flow can remain accepted by normal conntrack
state; these rules primarily govern new inbound connections. Tailscale also
manages its own netfilter rules; these NixOS exceptions do not replace tailnet
ACLs/grants or claim to enumerate every effective accept rule. SSH policy is
unchanged, and this change does not open port 22 on the physical LAN.

After building/reviewing and activating:

```sh
nmcli -t -f NAME,UUID,DEVICE connection show --active
sudo nft list set inet nixos-fw home-lan-interfaces
journalctl -u home-firewall-sync
```

Verify that the set follows approved profile connect/disconnect events and is
empty on an unapproved profile. Preserve another recovery path before changing
network/firewall policy. The regression check validates configuration and set
reconciliation with synthetic profile data; it does not probe network services.
