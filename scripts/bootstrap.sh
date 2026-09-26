#!/usr/bin/env bash
set -euo pipefail

flutter create --platforms=android,windows --org com.lanbridge --project-name lanbridge05 .
dart run tool/configure_platforms.dart
flutter pub get

echo
echo "LanBridge 05 platform files are ready."
echo "Windows: flutter run -d windows"
echo "Android: flutter run -d <device>"
