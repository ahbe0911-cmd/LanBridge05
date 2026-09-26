import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/lan_client.dart';
import '../widgets/app_shell.dart';
import 'mobile_session_screen.dart';

class MobilePairScreen extends StatefulWidget {
  const MobilePairScreen({super.key});

  @override
  State<MobilePairScreen> createState() => _MobilePairScreenState();
}

class _MobilePairScreenState extends State<MobilePairScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
  );

  bool _connecting = false;
  bool _handledCode = false;
  String? _error;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handledCode || _connecting || capture.barcodes.isEmpty) return;

    final value = capture.barcodes.first.rawValue;
    if (value == null || !value.startsWith('lanbridge://')) return;

    _handledCode = true;
    await _scannerController.stop();
    await _connect(value);
  }

  Future<void> _connect(String qrValue) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });

    LanClient? client;
    try {
      if (Platform.isAndroid) {
        final status = await Permission.accessLocalNetwork.request();
        if (!status.isGranted) {
          throw const FileSystemException(
            'Local network permission is required to connect to the PC.',
          );
        }
      }

      final pairing = PairingInfo.fromQr(qrValue);
      client = LanClient(pairing);
      await client.ping();

      if (!mounted) {
        client.close();
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MobileSessionScreen(
            client: client!,
            pairing: pairing,
          ),
        ),
      );
    } catch (error) {
      client?.close();
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _connecting = false;
        _handledCode = false;
      });
      await _scannerController.start();
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppShell(
        padding: EdgeInsets.zero,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        'Camera error: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0xFF07111F).withValues(alpha: 0.88),
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF07111F).withValues(alpha: 0.96),
                    ],
                    stops: const <double>[0, 0.30, 0.58, 1],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const BrandTitle(compact: true),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 248,
                        height: 248,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: const Color(0xFF4EE8C1),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 202,
                            height: 202,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Scan the QR on your PC',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'No cloud is used. Your phone connects directly to the Windows app over the same Wi-Fi/LAN.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              height: 1.45,
                            ),
                          ),
                          if (_connecting) ...<Widget>[
                            const SizedBox(height: 15),
                            const LinearProgressIndicator(),
                          ],
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFFFFA3A3),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
