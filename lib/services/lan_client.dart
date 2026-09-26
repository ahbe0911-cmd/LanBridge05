import 'dart:convert';
import 'dart:io';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';

class PairingInfo {
  const PairingInfo({
    required this.host,
    required this.port,
    required this.token,
  });

  final String host;
  final int port;
  final String token;

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: path,
      queryParameters: query,
    );
  }

  factory PairingInfo.fromQr(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'lanbridge' || uri.host != 'pair') {
      throw const FormatException('Invalid LanBridge QR code');
    }

    final host = uri.queryParameters['host'] ?? '';
    final port = int.tryParse(uri.queryParameters['port'] ?? '') ?? 0;
    final token = uri.queryParameters['token'] ?? '';

    if (host.isEmpty || port <= 0 || token.length < 16) {
      throw const FormatException('Incomplete pairing data');
    }

    return PairingInfo(host: host, port: port, token: token);
  }
}

class LanClient {
  LanClient(this.pairing);

  final PairingInfo pairing;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  void close() => _client.close(force: true);

  Future<void> ping() async {
    final request = await _client.getUrl(pairing.uri('/api/ping'));
    _authorize(request);
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Pairing failed (${response.statusCode}): $body');
    }
  }

  Future<void> uploadFile(
    File file, {
    required void Function(int sent, int total) onProgress,
  }) async {
    final total = await file.length();
    if (total > kMaxFileBytes) {
      throw const FileSystemException('File is larger than 500 MB');
    }

    await WakelockPlus.enable();
    try {
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'file.bin';

      final request = await _client.postUrl(
        pairing.uri('/api/upload', <String, String>{'name': fileName}),
      );
      _authorize(request);
      request.headers.contentType = ContentType.binary;
      request.headers.set(HttpHeaders.contentLengthHeader, '$total');

      var sent = 0;
      await for (final chunk in file.openRead()) {
        request.add(chunk);
        sent += chunk.length;
        onProgress(sent, total);
      }

      final response =
          await request.close().timeout(const Duration(minutes: 30));
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Upload failed (${response.statusCode}): $body');
      }
      onProgress(total, total);
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<ChatMessage> sendMessage(String text) async {
    final request = await _client.postUrl(pairing.uri('/api/chat'));
    _authorize(request);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(<String, dynamic>{'text': text}));

    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Message failed (${response.statusCode}): $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return ChatMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages({required int since}) async {
    final request = await _client.getUrl(
      pairing.uri('/api/chat', <String, String>{'since': '$since'}),
    );
    _authorize(request);
    final response = await request.close().timeout(const Duration(seconds: 10));
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Chat sync failed (${response.statusCode}): $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final items = data['messages'] as List<dynamic>? ?? <dynamic>[];
    return items
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _authorize(HttpClientRequest request) {
    request.headers.set('X-LanBridge-Token', pairing.token);
  }
}
