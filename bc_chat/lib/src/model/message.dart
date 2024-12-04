import 'package:bc_chat/src/model/chat_user.dart';
import 'package:bc_chat/src/model/message_content.dart';

class Message {
  DateTime date;
  int ver;
  String msgId;
  ChatUser from;
  String chId;
  MessageContent content;

  Message({required this.date, required this.ver, required this.msgId, required this.from, required this.chId, required this.content});

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
        date: DateTime.fromMillisecondsSinceEpoch(map['date']),
        ver: map['ver'],
        msgId: map['msgId'],
        from: ChatUser.fromMap(map['from']),
        chId: map['chId'],
        content: MessageContent.fromMap(map['content']));
  }

  Map<String, dynamic> toMap() {
    return {"date": date.millisecondsSinceEpoch, "ver": ver, "msgId": msgId, "from": from.toMap(), "chId": chId, "content": content.toMap()};
  }

  @override
  String toString() {
    return "Message(date: ${date.millisecondsSinceEpoch}, ver: $ver, msgId: $msgId, from: $from, chId: $chId, content: $content";
  }
}
