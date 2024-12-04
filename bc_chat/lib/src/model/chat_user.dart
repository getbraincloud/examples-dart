import 'package:flutter/material.dart';

class ChatUser {
  String id;
  String name;
  String pic;

  ChatUser({required this.id, required this.name, required this.pic});

  factory ChatUser.fromMap(Map<String,dynamic> map) {
    return ChatUser(id: map['id'], name: map['name'], pic: map['pic']);
  }
  Map<String,dynamic> toMap() {
    return {"id": id, "name": name, "pic": pic};
  }
  
  CircleAvatar getAvatar() {
    if (pic.isEmpty) return   const CircleAvatar( foregroundImage: AssetImage('assets/images/flutter_logo.png'),);

    return CircleAvatar(foregroundImage: Image.network(pic).image);
  }


  @override
  String toString() {
    return "ChatUser(id: $id, name: $name, pic: $pic)";
  }
}