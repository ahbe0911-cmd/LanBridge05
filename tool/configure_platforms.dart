import 'dart:io';

Future<void> main() async {
  await _configureAndroid();
}

Future<void> _configureAndroid() async {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!await manifest.exists()) return;

  var text = await manifest.readAsString();

  const permissions = <String>[
    'android.permission.INTERNET',
    'android.permission.CAMERA',
    'android.permission.ACCESS_LOCAL_NETWORK',
  ];

  for (final permission in permissions) {
    final line = '<uses-permission android:name="$permission" />';
    if (!text.contains(permission)) {
      text = text.replaceFirst(
        RegExp(r'<manifest[^>]*>'),
        (match) => '${match.group(0)}\n    $line',
      );
    }
  }

  text = text.replaceFirst(
    RegExp(r'android:label="[^"]*"'),
    'android:label="LanBridge 05"',
  );

  if (!text.contains('android:usesCleartextTraffic=')) {
    text = text.replaceFirst(
      '<application',
      '<application\n        android:usesCleartextTraffic="true"',
    );
  }

  await manifest.writeAsString(text);

  final kts = File('android/app/build.gradle.kts');
  if (await kts.exists()) {
    var gradle = await kts.readAsString();
    gradle = gradle.replaceAll(
      'compileSdk = flutter.compileSdkVersion',
      'compileSdk = 37',
    );
    gradle = gradle.replaceAll(
      'minSdk = flutter.minSdkVersion',
      'minSdk = 23',
    );
    gradle = gradle.replaceAll(
      'targetSdk = flutter.targetSdkVersion',
      'targetSdk = 37',
    );
    await kts.writeAsString(gradle);
  }

  final groovy = File('android/app/build.gradle');
  if (await groovy.exists()) {
    var gradle = await groovy.readAsString();
    gradle = gradle.replaceAll(
      'compileSdkVersion flutter.compileSdkVersion',
      'compileSdkVersion 37',
    );
    gradle = gradle.replaceAll(
      'minSdkVersion flutter.minSdkVersion',
      'minSdkVersion 23',
    );
    gradle = gradle.replaceAll(
      'targetSdkVersion flutter.targetSdkVersion',
      'targetSdkVersion 37',
    );
    await groovy.writeAsString(gradle);
  }
}
