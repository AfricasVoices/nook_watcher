import 'logger.dart';

Logger log = new Logger('model.dart');

class NeedsReplyData {
  String docId;
  DateTime datetime;
  DateTime earliestNeedsReplyDate;
  int needsReplyCount;
  int needsReplyAndEscalateCount;
  int needsReplyMoreThan24h;
  int needsReplyAndEscalateMoreThan24hCount;
  Map<String, int> needsReplyMessagesByDate;

  static NeedsReplyData fromSnapshot(DocSnapshot doc) =>
      fromData(doc.data)..docId = doc.id;

  static NeedsReplyData fromData(Map data) {
    if (data == null) return null;
    return NeedsReplyData()
      ..datetime = DateTime_fromData(data['datetime'])
      ..earliestNeedsReplyDate = DateTime_fromData(data['earliest_needs_reply_date'])
      ..needsReplyCount = int_fromData(data['needs_reply_count'])
      ..needsReplyAndEscalateCount = int_fromData(data['needs_reply_and_escalate_count'])
      ..needsReplyMoreThan24h = int_fromData(data['needs_reply_more_than_24h'])
      ..needsReplyAndEscalateMoreThan24hCount = int_fromData(data['needs_reply_and_escalate_more_than_24h'])
      ..needsReplyMessagesByDate = Map_fromData(data['needs_reply_messages_by_date'], int_fromData);
  }

  Map<String, dynamic> toData() {
    return {
      if (datetime != null) 'datetime': datetime.toIso8601String(),
      if (earliestNeedsReplyDate != null) 'earliest_needs_reply_date': datetime.toIso8601String(),
      if (needsReplyCount != null) 'needs_reply_count': needsReplyCount,
      if (needsReplyAndEscalateCount != null) 'needs_reply_and_escalate_count': needsReplyAndEscalateCount,
      if (needsReplyMoreThan24h != null) 'needs_reply_more_than_24h': needsReplyMoreThan24h,
      if (needsReplyAndEscalateMoreThan24hCount != null) 'needs_reply_and_escalate_more_than_24h': needsReplyAndEscalateMoreThan24hCount,
      if (needsReplyMessagesByDate != null) 'needs_reply_messages_by_date': needsReplyMessagesByDate,
    };
  }

  @override
  String toString() {
    return '$docId: ${toData()}';
  }
}

class User {
  String userName;
  String userEmail;
}

// ======================================================================
// Core firebase/yaml utilities

bool bool_fromData(data) {
  if (data == null) return null;
  if (data is bool) return data;
  if (data is String) {
    var boolStr = data.toLowerCase();
    if (boolStr == 'true') return true;
    if (boolStr == 'false') return false;
  }
  log.warning('unknown bool value: ${data?.toString()}');
  return null;
}

int int_fromData(data) {
  if (data == null) return null;
  if (data is int) return data;
  if (data is String) {
    var result = int.tryParse(data);
    if (result is int) return result;
  }
  log.warning('unknown int value: ${data?.toString()}');
  return null;
}

int num_fromData(data) {
  if (data == null) return null;
  if (data is num) return data;
  if (data is String) {
    var result = num.tryParse(data);
    if (result is num) return result;
  }
  log.warning('unknown num value: ${data?.toString()}');
  return null;
}

String String_fromData(data) => data?.toString();

DateTime DateTime_fromData(data) {
  if (data == null) return null;
  var datetime = DateTime.tryParse(data);
  if (datetime != null) return datetime;
  log.warning('unknown DateTime value: ${data?.toString()}');
  return null;
}

List<T> List_fromData<T>(dynamic data, T createModel(data)) =>
    (data as List)?.map<T>((elem) => createModel(elem))?.toList();

Map<String, T> Map_fromData<T>(dynamic data, T createModel(data)) =>
    (data as Map)?.map<String, T>((key, value) => MapEntry(key.toString(), createModel(value)));

Set<T> Set_fromData<T>(dynamic data, T createModel(data)) =>
    (data as List)?.map<T>((elem) => createModel(elem))?.toSet();

/// A snapshot of a document's id and data at a particular moment in time.
class DocSnapshot {
  final String id;
  final Map<String, dynamic> data;

  DocSnapshot(this.id, this.data);
}
