class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  final int id;
  final String sender;
  final String text;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      sender: json['sender'] as String? ?? 'Unknown',
      text: json['text'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
