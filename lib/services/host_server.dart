import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/constants.dart';
import '../models/chat_message.dart';

class ReceivedFile {
  const ReceivedFile({
    required this.name,
    required this.path,
    required this.bytes,
    required this.receivedAt,
  });

  final String name;
  final String path;
  final int bytes;
  final DateTime receivedAt;
}

class TransferProgress {
  const TransferProgress({
    required this.fileName,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final String fileName;
  final int receivedBytes;
  final int totalBytes;

  double? get fraction =>
      totalBytes > 0 ? receivedBytes / totalBytes.clamp(1, kMaxFileBytes) : null;
}

class LanHostServer {
  HttpServer? _server;
  late String token;
  late Directory receiveDirectory;

  final List<ChatMessage> _messages = <ChatMessage>[];
  int _nextMessageId = 1;

  DateTime? lastClientSeen;

  void Function()? onStateChanged;
  void Function(TransferProgress progress)? onTransferProgress;
  void Function(ReceivedFile file)? onFileReceived;

  int get port => _server?.port ?? 0;
  bool get isRunning => _server != null;
  List<ChatMessage> get messages => List<ChatMessage>.unmodifiable(_messages);

  Future<List<String>> localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address;
        if (_isPrivateIpv4(value) && !addresses.contains(value)) {
          addresses.add(value);
        }
      }
    }
    return addresses;
  }

  Future<void> start() async {
    if (_server != null) return;

    token = _generateToken();
    receiveDirectory = await _defaultReceiveDirectory();
    await receiveDirectory.create(recursive: true);

    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    _server!.listen(_handleRequest);
    onStateChanged?.call();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    onStateChanged?.call();
  }

  Uri pairingUri(String address) {
    return Uri(
      scheme: 'lanbridge',
      host: 'pair',
      queryParameters: <String, String>{
        'host': address,
        'port': '$port',
        'token': token,
        'v': '$kServerProtocolVersion',
      },
    );
  }

  void addLocalMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _messages.add(
      ChatMessage(
        id: _nextMessageId++,
        sender: 'Windows',
        text: clean,
        timestamp: DateTime.now(),
      ),
    );
    _trimMessages();
    onStateChanged?.call();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _setCorsHeaders(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    try {
      if (request.uri.path == '/api/ping') {
        if (!_authorized(request)) {
          await _json(request.response, HttpStatus.unauthorized, {
            'ok': false,
            'error': 'unauthorized',
          });
          return;
        }
        _touchClient();
        await _json(request.response, HttpStatus.ok, {
          'ok': true,
          'name': kAppName,
          'protocol': kServerProtocolVersion,
          'maxFileBytes': kMaxFileBytes,
        });
        return;
      }

      if (!_authorized(request)) {
        await _json(request.response, HttpStatus.unauthorized, {
          'ok': false,
          'error': 'unauthorized',
        });
        return;
      }

      _touchClient();

      if (request.method == 'POST' && request.uri.path == '/api/upload') {
        await _handleUpload(request);
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/api/chat') {
        await _handleChatPost(request);
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/api/chat') {
        await _handleChatGet(request);
        return;
      }

      await _json(request.response, HttpStatus.notFound, {
        'ok': false,
        'error': 'not_found',
      });
    } catch (error) {
      try {
        await _json(request.response, HttpStatus.internalServerError, {
          'ok': false,
          'error': 'server_error',
          'message': '$error',
        });
      } catch (_) {
        // Response may already be closed.
      }
    }
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final rawName = request.uri.queryParameters['name'] ?? 'file.bin';
    final safeName = _safeFileName(rawName);
    final total = request.contentLength;

    if (total > kMaxFileBytes) {
      await _json(request.response, HttpStatus.requestEntityTooLarge, {
        'ok': false,
        'error': 'file_too_large',
        'maxFileBytes': kMaxFileBytes,
      });
      return;
    }

    final target = await _uniqueTargetFile(safeName);
    IOSink? sink;
    var received = 0;

    try {
      sink = target.openWrite(mode: FileMode.writeOnly);

      await for (final chunk in request) {
        received += chunk.length;
        if (received > kMaxFileBytes) {
          throw const FileSystemException('File exceeds 500 MB limit');
        }
        sink.add(chunk);
        onTransferProgress?.call(
          TransferProgress(
            fileName: safeName,
            receivedBytes: received,
            totalBytes: total,
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final result = ReceivedFile(
        name: safeName,
        path: target.path,
        bytes: received,
        receivedAt: DateTime.now(),
      );
      onFileReceived?.call(result);
      onTransferProgress?.call(
        TransferProgress(
          fileName: safeName,
          receivedBytes: received,
          totalBytes: received,
        ),
      );

      await _json(request.response, HttpStatus.ok, {
        'ok': true,
        'name': safeName,
        'bytes': received,
        'path': target.path,
      });
    } catch (error) {
      if (sink != null) {
        await sink.close();
      }
      if (await target.exists()) {
        await target.delete();
      }

      final tooLarge = received > kMaxFileBytes;
      await _json(
        request.response,
        tooLarge
            ? HttpStatus.requestEntityTooLarge
            : HttpStatus.internalServerError,
        {
          'ok': false,
          'error': tooLarge ? 'file_too_large' : 'upload_failed',
          'message': '$error',
        },
      );
    }
  }

  Future<void> _handleChatPost(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final text = (data['text'] as String? ?? '').trim();

    if (text.isEmpty || text.length > 4000) {
      await _json(request.response, HttpStatus.badRequest, {
        'ok': false,
        'error': 'invalid_message',
      });
      return;
    }

    final message = ChatMessage(
      id: _nextMessageId++,
      sender: 'Android',
      text: text,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    _trimMessages();
    onStateChanged?.call();

    await _json(request.response, HttpStatus.ok, {
      'ok': true,
      'message': message.toJson(),
    });
  }

  Future<void> _handleChatGet(HttpRequest request) async {
    final since = int.tryParse(request.uri.queryParameters['since'] ?? '') ?? 0;
    final result = _messages.where((message) => message.id > since).toList();

    await _json(request.response, HttpStatus.ok, {
      'ok': true,
      'messages': result.map((message) => message.toJson()).toList(),
    });
  }

  void _touchClient() {
    lastClientSeen = DateTime.now();
    onStateChanged?.call();
  }

  bool _authorized(HttpRequest request) {
    final provided = request.headers.value('x-lanbridge-token');
    return provided != null && _constantTimeEquals(provided, token);
  }

  static Future<Directory> _defaultReceiveDirectory() async {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        return Directory('$home\\Downloads\\LanBridge05');
      }
    }
    return Directory(
      '${Directory.current.path}${Platform.pathSeparator}LanBridge05',
    );
  }

  static bool _isPrivateIpv4(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;

    final a = parts[0]!;
    final b = parts[1]!;
    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 100 && b >= 64 && b <= 127) return true;
    return false;
  }

  static String _safeFileName(String input) {
    var value = input
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    while (value.startsWith('.')) {
      value = value.substring(1);
    }
    if (value.isEmpty) value = 'file.bin';
    if (value.length > 180) {
      value = value.substring(value.length - 180);
    }
    return value;
  }

  Future<File> _uniqueTargetFile(String safeName) async {
    var candidate = File(
      '${receiveDirectory.path}${Platform.pathSeparator}$safeName',
    );
    if (!await candidate.exists()) return candidate;

    final dot = safeName.lastIndexOf('.');
    final base = dot > 0 ? safeName.substring(0, dot) : safeName;
    final ext = dot > 0 ? safeName.substring(dot) : '';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    candidate = File(
      '${receiveDirectory.path}${Platform.pathSeparator}${base}_$stamp$ext',
    );
    return candidate;
  }

  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  void _trimMessages() {
    const maxMessages = 500;
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }
  }

  static void _setCorsHeaders(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, X-LanBridge-Token',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
  }

  static Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, dynamic> payload,
  ) async {
    response.headers.contentType = ContentType.json;
    response.statusCode = status;
    response.write(jsonEncode(payload));
    await response.close();
  }
}
