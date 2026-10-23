// ==============================================================================
// DATA LAYER: TypeConverters
// Cashew sử dụng rộng rãi TypeConverter để lưu trữ các kiểu dữ liệu phức tạp
// (danh sách JSON, Enum tuỳ chỉnh, Map) vào các kiểu dữ liệu nguyên thủy của SQLite (TEXT).
// ==============================================================================

import 'dart:convert';
import 'package:drift/drift.dart';

/// Enum mức độ quan trọng/ưu tiên của tài liệu
enum DocumentPriority {
  low,
  medium,
  high,
}

/// Converter chuyển đổi danh sách các tag/từ khóa (`List<String>`) thành chuỗi JSON trong SQLite
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

/// Converter chuyển đổi Enum DocumentPriority thành String và ngược lại
class DocumentPriorityConverter extends TypeConverter<DocumentPriority, String> {
  const DocumentPriorityConverter();

  @override
  DocumentPriority fromSql(String fromDb) {
    switch (fromDb) {
      case 'high':
        return DocumentPriority.high;
      case 'medium':
        return DocumentPriority.medium;
      case 'low':
      default:
        return DocumentPriority.low;
    }
  }

  @override
  String toSql(DocumentPriority value) {
    return value.name;
  }
}
