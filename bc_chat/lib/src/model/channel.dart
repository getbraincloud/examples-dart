class Channel {
  String id;
  String type;
  String code;
  String name;
  String desc;
  Map<String, int> stats;

  Channel({required this.id, required this.type, required this.code, required this.name, required this.desc, required this.stats});

  factory Channel.fromMap(Map<String, dynamic> map) {
    Map<String, int> stats = {};
    if (map['stats'] is Map<String, dynamic>) {
      for (MapEntry<String, dynamic> entry in map['stats'].entries) {
        if (entry.value is int) {
          stats[entry.key] = entry.value;
        }
      }
    }
    return Channel(id: map['id'], code: map['code'], type: map['type'], name: map['name'], desc: map['desc'], stats: stats);
  }

  Map<String, dynamic> toMap() {
    return {"id": id, "type": type, "code": code, "name": name, "desc": desc, "stats": stats};
  }

  @override
  String toString() {
    return "Channel(id:$id,code:$code,type:$type,name:$name,desc:$desc,stats:$stats)";
  }


  // "id": "22682:gl:perfTest03",
  // "type": "gl",
  // "code": "perfTest03",
  // "name": "Perf Test 03",
  // "desc": "Distributed performance test",
  // "stats": {
  //   "messageCount": 0
  //   "memberCount": 2,
  //   "listenerCount": 0
  // }
}
