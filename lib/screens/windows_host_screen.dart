import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/chat_message.dart';
import '../services/host_server.dart';
import '../widgets/app_shell.dart';

class WindowsHostScreen extends StatefulWidget {
  const WindowsHostScreen({super.key});

  @override
  State<WindowsHostScreen> createState() => _WindowsHostScreenState();
}

class _WindowsHostScreenState extends State<WindowsHostScreen> {
  final LanHostServer _server = LanHostServer();
  final TextEditingController _chatController = TextEditingController();
  final List<ReceivedFile> _receivedFiles = <ReceivedFile>[];

  List<String> _addresses = <String>[];
  String? _selectedAddress;
  TransferProgress? _progress;
  Object? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _server.onStateChanged = _refresh;
    _server.onTransferProgress = (progress) {
      if (!mounted) return;
      setState(() => _progress = progress);
    };
    _server.onFileReceived = (file) {
      if (!mounted) return;
      setState(() {
        _receivedFiles.insert(0, file);
        _progress = null;
      });
    };
    _start();
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _start() async {
    try {
      await _server.start();
      final addresses = await _server.localAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddress = addresses.isNotEmpty ? addresses.first : null;
        _error = addresses.isEmpty
            ? 'No private IPv4 address was found. Connect this PC to Wi-Fi/Ethernet.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _clientConnected {
    final lastSeen = _server.lastClientSeen;
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen) < const Duration(seconds: 8);
  }

  void _sendLocalMessage() {
    final text = _chatController.text;
    if (text.trim().isEmpty) return;
    _server.addLocalMessage(text);
    _chatController.clear();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _chatController.dispose();
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = _selectedAddress;
    final qrData =
        address == null ? null : _server.pairingUri(address).toString();

    return Scaffold(
      body: AppShell(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const BrandTitle(),
                const Spacer(),
                _StatusPill(connected: _clientConnected),
              ],
            ),
            const SizedBox(height: 22),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: 390,
                          child: _buildPairingPanel(qrData),
                        ),
                        const SizedBox(width: 18),
                        Expanded(child: _buildActivityPanel()),
                        const SizedBox(width: 18),
                        SizedBox(width: 360, child: _buildChatPanel()),
                      ],
                    );
                  }

                  return ListView(
                    children: <Widget>[
                      _buildPairingPanel(qrData),
                      const SizedBox(height: 18),
                      SizedBox(height: 420, child: _buildActivityPanel()),
                      const SizedBox(height: 18),
                      SizedBox(height: 480, child: _buildChatPanel()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairingPanel(String? qrData) {
    final address = _selectedAddress;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Pair your phone',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Both devices must be on the same Wi-Fi/LAN. Scan this code from the Android app.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              width: 270,
              height: 270,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: qrData == null
                  ? const Center(child: CircularProgressIndicator())
                  : QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      gapless: false,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0B1427),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0B1427),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          if (_addresses.length > 1)
            DropdownButtonFormField<String>(
              value: _selectedAddress,
              dropdownColor: const Color(0xFF17243E),
              decoration: const InputDecoration(labelText: 'Network address'),
              items: _addresses
                  .map(
                    (value) =>
                        DropdownMenuItem<String>(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedAddress = value),
            )
          else if (address != null)
            _DetailRow(label: 'PC address', value: '$address:${_server.port}'),
          const SizedBox(height: 10),
          _DetailRow(
            label: 'Save folder',
            value: _server.isRunning ? _server.receiveDirectory.path : 'Starting…',
          ),
          const SizedBox(height: 14),
          Text(
            'Windows Firewall may ask for access. Allow Private networks so the phone can connect.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              '$_error',
              style: const TextStyle(color: Color(0xFFFFA3A3)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityPanel() {
    final progress = _progress;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Transfers',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                'Max 500 MB / file',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              ),
            ],
          ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4EE8C1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF4EE8C1).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    progress.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress.fraction),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatBytes(progress.receivedBytes)} / '
                    '${progress.totalBytes > 0 ? _formatBytes(progress.totalBytes) : 'unknown'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _receivedFiles.isEmpty
                ? Center(
                    child: Text(
                      'Received files will appear here.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _receivedFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final file = _receivedFiles[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.045),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: <Widget>[
                            const CircleAvatar(
                              backgroundColor: Color(0x184EE8C1),
                              foregroundColor: Color(0xFF4EE8C1),
                              child: Icon(Icons.insert_drive_file_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatBytes(file.bytes)} • ${file.path}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.50),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel() {
    final messages = _server.messages;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'LAN Chat',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Messages stay inside this session.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, reverseIndex) {
                      final message =
                          messages[messages.length - 1 - reverseIndex];
                      return _ChatBubble(message: message);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _chatController,
                  onSubmitted: (_) => _sendLocalMessage(),
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'Message your phone…',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _sendLocalMessage,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF4EE8C1) : const Color(0xFFFFC857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? 'Phone connected' : 'Waiting for phone',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final local = message.sender == 'Windows';
    return Align(
      alignment: local ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: local
              ? const Color(0xFF49A9FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message.text, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              '${message.sender} • '
              '${message.timestamp.hour.toString().padLeft(2, '0')}:'
              '${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
