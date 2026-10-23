// ==============================================================================
// CORE LAYER: Database Connection - Unsupported Fallback
// ==============================================================================

import 'package:drift/drift.dart';

QueryExecutor openConnection({String? dbName}) {
  throw UnsupportedError('Nền tảng này không được hỗ trợ để mở cơ sở dữ liệu SQLite.');
}
