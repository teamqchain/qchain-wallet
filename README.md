<p align="center">
  <img src="assets/images/QWallet_logo_uae.png" width="220" alt="QWallet logo" />
</p>

<h1 align="center">QWallet</h1>

<p align="center">
  <b>The QChain holder app: your post-quantum credentials, on your phone.</b><br/>
  Receive, hold and present digital credentials, with an ML-KEM-768 / ML-DSA-44 key pair that is generated and kept only on your device.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44-027DFD" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84" alt="Android | iOS" />
  <img src="https://img.shields.io/badge/PQC-ML--KEM--768%20%2B%20ML--DSA--44-6E40C9" alt="ML-KEM-768 + ML-DSA-44" />
  <img src="https://img.shields.io/badge/liboqs-Dart%20FFI-4B8BBE" alt="liboqs" />
  <img src="https://img.shields.io/badge/License-Proprietary-red" alt="License" />
</p>

---

## 📱 Install

QWallet is a **mobile install** (Android APK, iOS build), distributed by the team. There is no public web
version, by design:

> **Why not a web app?** The holder's key pair is generated and kept only on the device, so a browser build would
> mean a different key pair per browser, which breaks the one-key-pair-per-holder model. And QWallet's post-quantum
> library (liboqs, through `dart:ffi`) cannot compile for the web at all.

The app talks to the QChain API at `https://qchain.tail4fff4b.ts.net/api`. The organisations' side of the system is
the web portal [qchain-portal](https://github.com/teamqchain/qchain-portal).

> ⚠️ **It's a demo, not production.** The API runs on our university VM, so it may be offline at times, and the
> demo database is shared by everyone.

---

## Overview

**QChain** is a post-quantum credential system. Each credential carries an issuer signature made with
**ML-DSA-44 (CRYSTALS-Dilithium)** and is anchored on a permissioned **Hyperledger Fabric** ledger. The credential's
attributes live only on **IPFS**, encrypted to the holder's **ML-KEM-768** key.

**QWallet** is the holder's side. With it, a holder (a student or graduate, for example) can:

- **Activate** the wallet: register with their Emirates ID and generate their post-quantum key pair on the phone
- **Receive** credentials and decrypt them on the device
- **Hold** them, sorted by category, with full details and an A4 certificate view
- **Present** a credential to a verifier by QR code or one-time code, disclosing only the fields they choose
- **Approve or reject** verifier subscriptions (a verifier asking to be told if a credential is suspended or revoked)
- **Review** their activity history
- **Log out** from Settings, back to the animated splash screen, so another holder can sign in on the same phone
  (each holder's keys stay in secure storage, stored per Emirates ID)

---

## Post-quantum coverage

| What | Algorithm | Where it happens |
|------|-----------|------------------|
| Holder encryption key pair | **ML-KEM-768** | generated on the phone; private key in the platform's secure storage (`flutter_secure_storage`) |
| Holder signing key pair | **ML-DSA-44** | generated on the phone; private key in the platform's secure storage |
| Opening a credential | ML-KEM-768 envelope decryption | on the phone only; the backend never holds the private key |
| Presenting a credential | ML-DSA-44 signature over the presentation, bound to one credential ID | on the phone |
| Selective disclosure | salted SHA3-256 field fingerprints | the phone sends only the chosen fields and their salts; undisclosed values are never revealed |
| Checking the issuer | ML-DSA-44 issuer signature | verified by the backend against the ledger |

The post-quantum algorithms come from **liboqs** (Open Quantum Safe) through its Dart bindings.

---

## Architecture

```
          QWallet (Android / iOS)
   ┌───────────────────────────────────┐
   │ ML-KEM-768 + ML-DSA-44 key pair    │  ← generated here, never leaves the phone
   │ decrypt envelopes · sign           │
   │ presentations · selective          │
   │ disclosure                         │
   └───────────────────────────────────┘
                    │  HTTPS (JSON)
                    ▼
     https://qchain.tail4fff4b.ts.net/api   ──  Tailscale Funnel  ──▶  gateway (Nginx)
                                                                          │
                                                                          ▼
                                                       Go REST API  ·  qchain-backend
                                             ┌───────────────────┬───────────────┬──────────────┐
                                             ▼                   ▼               ▼              ▼
                                     Hyperledger Fabric       IPFS            MySQL       ML-DSA-44
                                     (ML-DSA-44 network)   (encrypted      (IDs, sessions,  issuer
                                                            envelopes)      subscriptions)  signatures
```

- **API address.** Compiled into the app with `--dart-define=API_BASE_URL=…` (`lib/utils/app_config.dart`); without it,
  the app uses `http://localhost:3000`.
- **Certificate rendering** comes from the shared package [qchain-shared](https://github.com/teamqchain/qchain-shared),
  which QPortal uses too.

---

## Technology stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.44 (Android, iOS), Dart ^3.9.2 |
| Post-quantum cryptography | `liboqs` ^2.1.0 (ML-KEM-768, ML-DSA-44), `pointycastle` ^4.0.0 |
| Key storage | `flutter_secure_storage` ^11.1.1 |
| State management and routing | GetX (`get` ^4.7.3) |
| HTTP | `http` ^1.6.0; `alice` / `alice_http` (in-app HTTP inspector for debugging) |
| Development | `device_preview` ^3.0.0 (preview the app on other screen sizes) |
| QR codes | `qr_flutter` ^4.1.0 |
| UI | `flutter_svg`, `phosphor_flutter`, `card_swiper`, `flutter_card_swiper`, `flutter_swiper_view`, `url_launcher` |
| Certificate template and viewer | `qchain_shared` (git dependency on qchain-shared) |

---

## Repository structure

```
qchain-wallet/
├── lib/
│   ├── main.dart                 # entry point
│   ├── screens/                  # splash (animated logo; double-tap opens the developer config),
│   │                             #   onboarding, register holder, home, wallet, receive, document detail,
│   │                             #   certificate viewer, present, selective disclosure, subscriptions,
│   │                             #   activity, settings (incl. Log Out), app logs, developer config
│   ├── services/                 # crypto_service.dart (key pair, decryption, signing) and the API client
│   ├── controllers/              # GetX controllers: wallet, activity, add document, subscriptions
│   ├── components/ widgets/      # reusable UI pieces
│   ├── skeletons/ Headers/       # loading placeholders and page headers
│   ├── model/ routes/ view/      # data models, navigation, page layout
│   ├── theme/                    # colours and text styles
│   └── utils/                    # app_config.dart (API_BASE_URL, build label), logger
├── assets/                       # fonts, logos, launcher icon images
├── android/ ios/                 # mobile platform projects
├── linux/ macos/ windows/ web/   # Flutter platform folders (not used: QWallet is mobile-only)
├── test/                         # widget tests
├── pubspec.yaml · pubspec.lock   # dependencies (qchain_shared pinned by commit in the lock file)
└── LICENSE
```

---

## Getting started

### Prerequisites

- Flutter **3.44.0** (Dart 3.10 or newer is needed by liboqs)
- Android SDK (for Android) and/or Xcode on macOS (for iOS)
- A phone or emulator, and network access to the QChain API

### 1. Clone

```bash
git clone https://github.com/teamqchain/qchain-wallet.git
cd qchain-wallet
```

### 2. Install the dependencies

```bash
flutter pub get        # also fetches qchain-shared from GitHub
```

### 3. Run on a device

```bash
flutter run --dart-define=API_BASE_URL=https://qchain.tail4fff4b.ts.net/api
```

### 4. Build

```bash
# Android APK
flutter build apk --release --dart-define=API_BASE_URL=https://qchain.tail4fff4b.ts.net/api

# iOS (on macOS, with signing set up in Xcode)
flutter build ipa --release --dart-define=API_BASE_URL=https://qchain.tail4fff4b.ts.net/api
```

Bump `kAppBuildNumber` in `lib/utils/app_config.dart` before each build you want to tell apart; the splash screen shows it.

---

## Working with qchain-shared

The certificate template and viewer live in [qchain-shared](https://github.com/teamqchain/qchain-shared) so that one
change shows up in both QWallet and QPortal.

- **Taking a shared update:** `flutter pub upgrade qchain_shared`, check the app, commit `pubspec.lock`, push, rebuild.
  `pubspec.lock` pins the exact commit, so a change in shared never reaches the wallet until you take it.
- **Editing shared and the wallet together:** clone both side by side and create `pubspec_overrides.yaml`
  (gitignored):

  ```yaml
  dependency_overrides:
    qchain_shared:
      path: ../qchain-shared
  ```

  Delete it and run `flutter pub get` before committing a `pubspec.lock` change.

---

## Related repositories

| Repository | What it holds |
|------------|---------------|
| [qchain-portal](https://github.com/teamqchain/qchain-portal) | QPortal, the web portal for issuers, verifiers and IT admins |
| [qchain-wallet](https://github.com/teamqchain/qchain-wallet) | QWallet, the holder's mobile app (this repository) |
| [qchain-shared](https://github.com/teamqchain/qchain-shared) | the shared Flutter package: certificate template and viewer |
| [qchain-backend](https://github.com/teamqchain/qchain-backend) | the Go REST API, MySQL schema, gateway, CI/CD and end-to-end tests |
| [qchain-network](https://github.com/teamqchain/qchain-network) | the Hyperledger Fabric network with ML-DSA-44 identities, and the chaincode |
| [qchain-docs](https://github.com/teamqchain/qchain-docs) | reports, the setup guide and the preliminary benchmarks |
| [qchain-kpi](https://github.com/teamqchain/qchain-kpi) | the post-quantum performance benchmarks |
| [teamqchain.github.io](https://github.com/teamqchain/teamqchain.github.io) | the project website |

Some of these repositories are private.

---

## Team

A University of Sharjah capstone project, supervised by **Dr. Manar Abu Talib** and **Dr. Sohail Abbas**.

| Member | Role |
|--------|------|
| Mohammed Bin Ali Maqqavi ([@M0hd-Maqqavi](https://github.com/M0hd-Maqqavi)) | Project Manager |
| Mohammed Abdul Haris ([@mohammed-ah-14](https://github.com/mohammed-ah-14)) | Technical Lead |
| Mohammed Nihal ([@nihvp](https://github.com/nihvp)) | Quality Assurance Lead |
| Mohammed Obeid ([@MohammedObeid88](https://github.com/MohammedObeid88)) | Blockchain Specialist |

---

## License

**Proprietary — all rights reserved.** © 2026 QChain. This source code is proprietary and confidential;
unauthorized copying, modification, distribution, or use is prohibited without prior written permission.
See [LICENSE](LICENSE).

---

## Disclaimer

This is an academic research project, not a production system. The demo uses seed/demo data on a shared database,
and the OTP/QR presentation flow is not yet gated behind holder authentication (tracked for a future session/login
system). Credential confidentiality and holder-key handling are implemented today: attributes are encrypted
end-to-end to an ML-KEM-768 key pair generated and held only on the holder's device, never transmitted to or stored
by the backend.
