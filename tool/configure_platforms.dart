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
      text = text.replaceFirstMapped(
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


  final mainActivity = File(
    'android/app/src/main/kotlin/com/lanbridge/lanbridge05/MainActivity.kt',
  );
  if (await mainActivity.exists()) {
    await mainActivity.writeAsString(r'''package com.lanbridge.lanbridge05

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "lanbridge05/local_network"
    private val requestCode = 4205
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            if (call.method != "requestLocalNetwork") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT < 37) {
                result.success(true)
                return@setMethodCallHandler
            }

            if (checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                result.success(true)
                return@setMethodCallHandler
            }

            if (pendingResult != null) {
                result.error("busy", "A permission request is already active.", null)
                return@setMethodCallHandler
            }

            pendingResult = result
            requestPermissions(
                arrayOf(Manifest.permission.ACCESS_LOCAL_NETWORK),
                requestCode
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != this.requestCode) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingResult?.success(granted)
        pendingResult = null
    }
}
''');
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
