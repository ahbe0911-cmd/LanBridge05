import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';
import '../services/lan_client.dart';
import '../widgets/app_shell.dart';

class MobileSessionScreen extends StatefulWidget {
  const MobileSessionScreen({
    super.key,
    required this.client,
    required this.pairing,
  });

  final LanClient client;
  final PairingInfo pairing;

  @override
  State<MobileSessionScreen> createState() => _MobileSessionScreenState();
}

class _MobileSessionScreenState extends State<MobileSessionScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = <ChatMessage>[];

  Timer? _pollTimer;
  double? _uploadProgress;
  String? _uploadName;
  String? _notice;
  bool _sendingMessage = false;
  int _lastMessageId = 0;

  @override
  void initState() {
    super.initState();
    _syncChat();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _syncChat(silent: true),
    );
  }

  Future<void> _pickAndSendFile() async {
    if (_uploadProgress != null) return;

    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (path == null) return;

    final file = File(path);
    final length = await file.length();
    if (length > kMaxFileBytes) {
      _showNotice('This file is larger than the 500 MB limit.');
      return;
    }

    final name = picked!.name;
    setState(() {
      _uploadName = name;
      _uploadProgress = 0;
      _notice = null;
    });

    try {
      await widget.client.uploadFile(
        file,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = total > 0 ? sent / total : null;
          });
        },
      );
      _showNotice('$name sent successfully.');
    } catch (error) {
      _showNotice('Transfer failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress = null;
          _uploadName = null;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    try {
      final message = await widget.client.sendMessage(text);
      _chatController.clear();
      _mergeMessages(<ChatMessage>[message]);
    } catch (error) {
      _showNotice('Could not send message: $error');
    } finally {
      if (mounted) setState(() => _sendingMessage = false);
    }
  }

  Future<void> _syncChat({bool silent = false}) async {
    try {
      final incoming = await widget.client.getMessages(since: _lastMessageId);
      _mergeMessages(incoming);
    } catch (error) {
      if (!silent) _showNotice('Chat sync failed: $error');
    }
  }

  void _mergeMessages(List<ChatMessage> incoming) {
    if (incoming.isEmpty || !mounted) return;

    final ids = _messages.map((message) => message.id).toSet();
    for (final message in incoming) {
      if (ids.add(message.id)) {
        _messages.add(message);
      }
      if (message.id > _lastMessageId) {
        _lastMessageId = message.id;
      }
    }
    _messages.sort((a, b) => a.id.compareTo(b.id));
    setState(() {});
  }

  void _showNotice(String value) {
    if (!mounted) return;
    setState(() => _notice = value);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chatController.dispose();
    widget.client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sending = _uploadProgress != null;

    return Scaffold(
      body: AppShell(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const BrandTitle(compact: true),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4EE8C1).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: Color(0xFF4EE8C1),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'LAN paired',
                        style: TextStyle(
                          color: Color(0xFF4EE8C1),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Send a file to Windows',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '≤ 500 MB',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    sending
                        ? (_uploadName ?? 'Sending…')
                        : 'Files stream directly over Wi-Fi and are not loaded fully into memory.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      height: 1.4,
                    ),
                  ),
                  if (sending) ...<Widget>[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 7),
                    Text(
                      _uploadProgress == null
                          ? 'Sending…'
                          : '${((_uploadProgress ?? 0) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: sending ? null : _pickAndSendFile,
                    icon: Icon(
                      sending ? Icons.sync_rounded : Icons.upload_file_rounded,
                    ),
                    label: Text(sending ? 'Sending…' : 'Choose file'),
                  ),
                ],
              ),
            ),
            if (_notice != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _notice!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'LAN Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _messages.isEmpty
                          ? Center(
                              child: Text(
                                'Send a message to the PC.',
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.43),
                                ),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              itemCount: _messages.length,
                              itemBuilder: (context, reverseIndex) {
                                final message = _messages[
                                    _messages.length - 1 - reverseIndex];
                                return _MobileChatBubble(message: message);
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            maxLength: 4000,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              hintText: 'Type a message…',
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sendingMessage ? null : _sendMessage,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
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

class _MobileChatBubble extends StatelessWidget {
  const _MobileChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.sender == 'Android';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? const Color(0xFF4EE8C1).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
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
