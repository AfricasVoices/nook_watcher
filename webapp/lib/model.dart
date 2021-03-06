import 'logger.dart';

Logger log = new Logger('model.dart');

class ConversationMetricsData {
  String docId;
  DateTime datetime;
  int conversationsCount;
  Map<String, int> tagsCount;

  static ConversationMetricsData fromSnapshot(DocSnapshot doc) =>
      fromData(doc.data)..docId = doc.id;

  static ConversationMetricsData fromData(Map data) {
    print(data);
    if (data == null) return null;
    return ConversationMetricsData()
      ..datetime = DateTime_fromData(data['datetime'])
      ..conversationsCount = int_fromData(data['conversations_count'])
      ..tagsCount = Map_fromData(data['tags_count'], int_fromData) ?? {};
  }

  Map<String, dynamic> toData() {
    return {
      if (datetime != null) 'datetime': datetime.toIso8601String(),
      if (conversationsCount != null) 'conversations_count': conversationsCount,
      if (tagsCount != null) 'tags_count': tagsCount,
    };
  }

  @override
  String toString() {
    return '$docId: ${toData()}';
  }
}

class DriverData {
  String docId;
  DateTime datetime;
  Map<String, int> metrics;

  static DriverData fromSnapshot(DocSnapshot doc) =>
      fromData(doc.data)..docId = doc.id;

  static DriverData fromData(Map data) {
    if (data == null) return null;
    DateTime datetime = DateTime_fromData(data['datetime']);
    Map<String, int> metrics = {};
    data.forEach((key, value) {
      if (key == 'datetime') return;
      metrics[String_fromData(key)] = int_fromData(value);
    });
    return DriverData()
      ..datetime = datetime
      ..metrics = metrics;
  }

  Map<String, dynamic> toData() {
    return {
      if (datetime != null) 'datetime': datetime.toIso8601String(),
      ...metrics,
    };
  }

  @override
  String toString() {
    return '$docId: ${toData()}';
  }
}

class SystemEventsData {
  String docId;
  String event;
  String hostname;
  String systemName;
  DateTime timestamp;

  static SystemEventsData fromSnapshot(DocSnapshot doc) =>
      fromData(doc.data)..docId = doc.id;

  static SystemEventsData fromData(Map data) {
    if (data == null) return null;
    return SystemEventsData()
      ..event = data['event']
      ..hostname = data['hostname']
      ..systemName = data['system_name']
      ..timestamp = DateTime_fromData(data['timestamp']);
  }

  Map<String, dynamic> toData() {
    return {
      if (event != null) 'event': event,
      if (hostname != null) 'hostname': hostname,
      if (systemName != null) 'system_name': systemName,
      if (timestamp != null) 'timestamp': timestamp.toIso8601String()
    };
  }

  @override
  String toString() {
    return '$docId: ${toData()}';
  }
}


class SystemMetricsData {
  String docId;
  DateTime datetime;
  Map<String, double> cpuLoadIntervalPercent;
  double cpuPercent;
  Map<String, double> diskUsage;
  Map<String, double> memoryUsage;

  static SystemMetricsData fromSnapshot(DocSnapshot doc) =>
    fromData(doc.data)..docId = doc.id;

  static SystemMetricsData fromData(Map data) {
    if (data == null) return null;
    return SystemMetricsData()
      ..datetime = DateTime_fromData(data['datetime'])
      ..cpuLoadIntervalPercent =  Map_fromData(data['cpu_load_interval_percent'], double_fromData)
      ..cpuPercent = double_fromData(data['cpu_percent'])
      ..diskUsage = Map_fromData(data['disk_usage'], double_fromData)
      ..memoryUsage = Map_fromData(data['memory_usage'], double_fromData);
  }

  Map<String, dynamic> toData() {
    return {
      if (datetime != null) 'datetime': datetime.toIso8601String(),
      if (cpuLoadIntervalPercent != null) 'cpu_load_interval_percent': cpuLoadIntervalPercent,
      if (cpuPercent != null) 'cpu_percent': cpuPercent,
      if (diskUsage != null) 'disk_usage': diskUsage,
      if (memoryUsage != null) 'memory_usage': memoryUsage
    };
  }

  static double sizeInGB(double bytes) =>
      double.parse((bytes / (1024.0 * 1024.0 * 1024.0)).toStringAsFixed(1));

  @override
  String toString() {
    return '$docId: ${toData()}';
  }
}

class DirectorySizeMetricsData {
  String docId;
  String  project;
  String dirname;
  DateTime timestamp;
  double sizeInMB;

  static DirectorySizeMetricsData fromSnapshot(DocSnapshot doc) =>
      fromData(doc.data)..docId = doc.id;

  static DirectorySizeMetricsData fromData(Map data) {
    if (data == null) return null;
    return DirectorySizeMetricsData()
      ..project = data['project']
      ..dirname = data['dirname']
      ..timestamp = DateTime_fromData(data['timestamp'])
      ..sizeInMB = double_fromData(data['size_in_mb']);
  }

  Map<String, dynamic> toData() {
    return {
      'project': project,
      if (dirname != null) 'dirname': dirname,
      if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
      if (sizeInMB != null) 'size_in_mb': sizeInMB
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

class DataModelNotSupported implements Exception {
  String cause;
  DataModelNotSupported(this.cause);
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

double double_fromData(data) {
  if (data == null) return null;
  if (data is double) return data;
  if (data is String) {
    var result = double.tryParse(data);
    if (result is double) return result;
  }
  log.warning('unknown double value: ${data?.toString()}');
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
