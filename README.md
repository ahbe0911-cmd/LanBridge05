# LanBridge 05

LanBridge 05 is a local-network bridge between **Android** and **Windows 10/11**.  
The Windows app displays a one-time QR code. The Android app scans it and connects directly to the PC over the same Wi-Fi/LAN.

## Current MVP

- QR pairing with a random per-session token
- Android → Windows file transfer
- Streaming upload: the complete file is never loaded into RAM
- Hard server-side limit of **500 MB per file**
- Transfer progress on both devices
- Android screen stays awake during an active transfer
- Two-way LAN chat
- Received files are saved to `Downloads\LanBridge05` on Windows
- No cloud relay and no account required
- GitHub Actions builds an Android APK and a portable Windows x64 ZIP

## How it works

1. Start LanBridge 05 on the Windows PC.
2. Allow Windows Firewall access for **Private networks** if prompted.
3. Make sure the phone and PC are connected to the same router / LAN.
4. Open the Android app and scan the QR code shown on Windows.
5. Choose a file on Android or start chatting.

The QR contains the PC's local IPv4 address, a temporary port, and a cryptographically random session token. The token changes every time the Windows host starts.

## Build locally

Install a current stable Flutter SDK.

### Windows

```powershell
.\scripts\bootstrap.ps1
flutter run -d windows
```

### Android

After bootstrap, connect an Android device with USB debugging enabled:

```powershell
flutter devices
flutter run -d <device-id>
```

## GitHub Actions artifacts

Every push to `main` runs `.github/workflows/build.yml`.

After a successful workflow run, open **Actions → Build LanBridge 05 → Artifacts** and download:

- `LanBridge05-Android` — contains the release APK
- `LanBridge05-Windows-x64` — portable Windows release ZIP

## Android 17 local-network permission

The project targets Android API 37 and declares `ACCESS_LOCAL_NETWORK`. The app requests this runtime permission before opening a LAN connection. This is required for direct local-network access when targeting Android 17+.

## Security notes

This MVP is designed for a trusted home/office LAN:

- Pairing uses a random token that is not stored permanently.
- Requests without the token are rejected.
- Received filenames are sanitized to prevent path traversal.
- The 500 MB limit is enforced by the Windows server even if a client bypasses the UI.
- File data is streamed directly to disk.

Traffic is currently plain HTTP on the local network. A production hardening phase can add encrypted transport with certificate/key pinning established by the QR code.

## Roadmap

- Windows → Android file transfer
- Transfer pause/resume and retry
- Multi-file queue
- mDNS device discovery as an alternative to QR
- End-to-end encrypted LAN transport
- Windows installer and app signing
- Android signing/release workflow
