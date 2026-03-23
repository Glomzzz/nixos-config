# Problems

- Moving imports and changing package ownership in the same commit is the main build-break risk.
- Wrapper imports may be needed briefly during migration, but they must be removed immediately after the dependent move lands.
- Package moves can silently affect PATH and availability for root, systemd services, and early-session tooling if ownership boundaries are not checked carefully.
- The final audit wave must account for still-active `modules/home/**` wrappers that import legacy `home/**` leaves; otherwise the coherence matrix can falsely claim a clean final tree while active legacy files remain reachable.
