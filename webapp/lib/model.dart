class MetricsSnapshot {
  String docId;
  Map data;

  static MetricsSnapshot fromData(Map data) {
    if (data == null) return null;
    assert(data.length == 1);
    return MetricsSnapshot()
      ..docId = data.keys.first
      ..data = data.values.first;
  }

  Map<String, dynamic> toData() {
    return data;
  }

  @override
  String toString() {
    // TODO: implement toString
    return '$docId: $data';
  }
}

class User {
  String userName;
  String userEmail;
}
