$ErrorActionPreference = "Stop"

flutter config --enable-windows-desktop
flutter create --platforms=android,windows --org com.lanbridge --project-name lanbridge05 .
dart run tool/configure_platforms.dart
flutter pub get

Write-Host ""
Write-Host "LanBridge 05 platform files are ready."
Write-Host "Windows: flutter run -d windows"
Write-Host "Android: flutter run -d <device>"
