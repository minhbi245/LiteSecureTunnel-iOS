# LiteSecureTunnel-iOS

Minimal iOS WireGuard VPN client. Built as interview take-home exercise.

## Overview

SwiftUI app with a single Connect toggle. On a physical device with a paid Apple Developer account, it routes traffic through a self-hosted WireGuard server via `NEPacketTunnelProvider`. On the iOS Simulator, high-security features are disabled and an explanatory alert is shown (per the assignment spec).

## Status

| Component | State |
|---|---|
| SwiftUI UI + alert | ✅ Done |
| Simulator detection | ✅ Done |
| Keychain storage (private key, device-only) | ✅ Done |
| App Group + Network Extension target scaffolding | ✅ Done |
| `NETunnelProviderManager` wrapper (start/stop/status) | ✅ Done |
| wg-easy Docker server (LAN) | ✅ Done |
| `PacketTunnelProvider` + `WireGuardAdapter` integration code | ✅ Written (guarded by `#if canImport(WireGuardKit) && !targetEnvironment(simulator)`) |
| **WireGuardKit linked + running on device** | ⏸️ Pending paid Apple Developer account |

### Why WireGuardKit is deferred

Two hard blockers, both pending access to a paid Apple Developer Program membership:

1. **Network Extension entitlement is gated to paid teams.** Personal/free Apple ID teams cannot provision the `com.apple.developer.networking.networkextension` capability. Xcode surfaces this explicitly:
   > *"Personal development teams do not support the Network Extensions capability."*

   Without it, the extension cannot be signed and installed on a physical device — and the tunnel cannot run on Simulator regardless (iOS limitation).

2. **WireGuardKit binary dependencies require device-specific builds.** `libwg-go.a` must be compiled per-platform (iOS device vs Simulator) via the upstream Makefile. With Xcode 26 and Swift 6's new explicit module build system, the standard SPM path exhibits compiler crashes and linker errors. The clean fix is a Run Script build phase that rebuilds `libwg-go.a` for the current platform — which requires device provisioning to be testable end-to-end.

Both issues resolve once a paid account is available.

### Behavior today

- Simulator: alert is shown, toggle is disabled — **matches assignment requirement exactly.** Build succeeds without WireGuardKit linked.
- Physical device (personal team): app builds + runs, but tunnel cannot start because Network Extension entitlement is paid-only. `startTunnel` returns a stub error.
- DEBUG seeder pre-populates Keychain private key and `TunnelConfiguration` from the wg-easy `ios-test` client so the full path is one integration step away.

### Enabling the tunnel on device (when paid account is available)

The Phase 4 code in `PacketTunnelProvider.swift` is already written — it's gated behind `#if canImport(WireGuardKit) && !targetEnvironment(simulator)`. To activate:

1. Clone wireguard-apple locally:
   ```bash
   cd LiteSecureTunnel-iOS
   git clone https://git.zx2c4.com/wireguard-apple
   ```
2. In Xcode: **File → Add Package Dependencies → Add Local...** → select the cloned `wireguard-apple/` folder → add `WireGuardKit` product to the **PacketTunnel** target only
3. Add a **Run Script** build phase to the PacketTunnel target (above Compile Sources) that calls:
   ```bash
   "${SRCROOT}/../scripts/build-wireguard-go.sh"
   ```
   The script (included in this repo) builds `libwg-go.a` via Go toolchain for the current platform. Install Go first: `brew install go`.
4. Set the paid team in **Signing & Capabilities** for both targets.
5. Build for a physical device — `startTunnel` will now invoke `WireGuardAdapter` and bring the tunnel up against wg-easy.

The simulator path stays stubbed because NE does not run on Simulator regardless.

## Requirements

- Xcode 15+ (tested on Xcode 26 beta)
- iOS 16+ physical device for tunneling (Simulator supported for UI + detection test)
- **Paid** Apple Developer account for Network Extension entitlement
- Docker Desktop for local WireGuard server

## Architecture

```
LiteSecureTunnel-iOS/
├── App/                  LiteSecureTunnel_iOSApp (@main)
├── Views/                TunnelView                   — Connect toggle + alert
├── ViewModels/           TunnelViewModel              — VPN state, DEBUG seeder
├── Services/
│   ├── VPNManager                                     — NETunnelProviderManager wrapper
│   ├── KeychainStore                                  — Private key (device-only)
│   ├── AppGroupConfigStore                            — Non-secret config shared w/ extension
│   └── SimulatorDetector                              — Compile-time + runtime check
├── Models/
│   └── TunnelConfiguration                            — Codable struct
└── PacketTunnel/         NE target
    ├── PacketTunnelProvider                           — WireGuardAdapter integration (guarded)
    └── Logger                                         — os_log subsystems for lifecycle/config/network

scripts/
└── build-wireguard-go.sh  Run Script phase — rebuilds libwg-go.a per platform

server/
└── docker-compose.yml    wg-easy WireGuard server (LAN)
```

**MVVM separation.** The view has no business logic. The view model binds to `VPNManager.$status` via Combine and surfaces `NEVPNStatus` as user-facing text.

## Setup

### 1. Clone and open

```bash
git clone <repo>
cd LiteSecureTunnel-iOS/LiteSecureTunnel-iOS
open LiteSecureTunnel-iOS.xcodeproj
```

### 2. Signing

Both targets (`LiteSecureTunnel-iOS`, `PacketTunnel`) must use the same paid team. Bundle IDs listed below — update if forking.

### 3. Start the WireGuard server

```bash
cd server
docker compose up -d
```

Admin UI: http://localhost:51821 (set `PASSWORD_HASH` in `docker-compose.yml` via `docker run -it ghcr.io/wg-easy/wg-easy wgpw YOUR_PASSWORD`).

### 4. Seed a client config

1. Web UI → **New Client** → name `ios-test` → Download `.conf`
2. Copy values into `TunnelViewModel.devSampleConfig()` + `devPrivateKey`
3. App populates Keychain on first launch (DEBUG build only)

### 5. Run

- Simulator: alert appears, toggle disabled (requirement check)
- Device: tap Connect → iOS VPN permission dialog → tunnel connects

## Security Model

Minimum viable security for a WireGuard client. Scope chosen per YAGNI.

### Implemented

- **Private key**: iOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and a Keychain Access Group shared between app and extension. Never synced via iCloud, never backed up.
- **App ↔ Extension IPC**: App Group shared container. Only non-secret routing data (endpoint, allowed IPs) passes through `providerConfiguration`; the private key is read from Keychain on the extension side.
- **Transport**: Delegated entirely to the WireGuard protocol (ChaCha20-Poly1305, Curve25519, BLAKE2s). No app-layer crypto.
- **Simulator detection**: Compile-time `#if targetEnvironment(simulator)` plus runtime env fallback. Not a security boundary — a UX/expectation cue per the assignment spec.

### Out of Scope (Production Hardening)

Consciously deferred. A production deployment would address these via:

- **Environment separation**: `.xcconfig` files + build configurations for staging/prod endpoints (preferred over duplicated targets)
- **Config-driven endpoints**: Server hostnames, ports, routing policies loaded from environment-specific plists
- **Observability**: Crash reporting (Sentry/Crashlytics), structured logging, analytics with consent
- **Advanced hardening**: Jailbreak detection, anti-debugging, Secure Enclave-backed key storage, MDM integration
- **Key management**: Biometric gate on tunnel start, key rotation policy
- **Distribution**: TestFlight + App Store Connect pipeline, provisioning profile automation
- **Certificate pinning**: Not applicable to WireGuard UDP — called out so it isn't expected

These are **recognized but not implemented** — single-user, single-environment, LAN-only interview scope does not justify the complexity.

## Known Limitations

1. **NE requires paid Dev account** — documented above; blocks real tunneling today.
2. **Simulator cannot tunnel** — iOS platform limit; app shows alert accordingly.
3. **Config ingestion is DEBUG-seeded** — production would add a `.conf` file picker or QR scan.
4. **LAN-only server** — wg-easy runs on the developer Mac; interviewer cannot test from their own network. Demo video recommended.

## Testing

### Manual checklist

| Scenario | Expected |
|---|---|
| Launch on Simulator | Alert "Simulator Detected" appears, toggle disabled |
| Launch on device (first run) | No alert |
| Tap Connect (device, with paid acct + WireGuardKit) | iOS VPN permission → Connecting → Connected |
| Safari → ifconfig.me (connected) | Shows server/egress IP, not carrier |
| Toggle off | Disconnected, IP reverts |
| Relaunch app | State persists, no re-permission prompt |
| Airplane mode while connected | Status reflects failure |
| Reboot device | Keychain item still accessible after first unlock |

### Unit tests

Scoped to testable services (NE tunneling itself cannot be unit-tested meaningfully):

- `SimulatorDetectorTests` — Simulator returns `true`
- `TunnelConfigurationTests` — Codable round-trip

Run: `⌘U` in Xcode, or `xcodebuild test` from CLI.

Keychain is untested at unit level — the test target does not have Keychain Sharing entitlement, so it would fail with `errSecMissingEntitlement`. Keychain behavior is covered by the manual E2E checklist above.

## Identifiers

| Item | Value |
|---|---|
| App Bundle ID | `com.leonguyen.LiteSecureTunnel-iOS` |
| Extension Bundle ID | `com.leonguyen.LiteSecureTunnel-iOS.PacketTunnel` |
| Team ID | `2BWXQ8ACBB` |
| App Group | `group.com.leonguyen.LiteSecureTunnel-iOS` |
| Keychain Access Group | `2BWXQ8ACBB.com.leonguyen.LiteSecureTunnel-iOS` |
