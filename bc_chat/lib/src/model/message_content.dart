class MessageContent {
  String text;
  Map<String,dynamic>? rich;

  MessageContent({required this.text, this.rich});

  factory MessageContent.fromMap(Map<String,dynamic> map) {
    return MessageContent(text: map['text'], rich: map['rich']);
  }

  Map<String,dynamic> toMap() {
    Map<String,dynamic> map = {"text":text};
    if (rich != null) {
      map['rich'] = rich;
    }
    return map;
  }

  @override
  String toString() {
    return "MessageContent(text:$text, rich:$rich)";
  }

}