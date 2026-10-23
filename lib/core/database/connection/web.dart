// ==============================================================================
// CORE LAYER: Database Connection - Web (WasmDatabase)
// Hỗ trợ SQLite trên Web thông qua WebAssembly (sqlite3.wasm & drift_worker.js)
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import '../../constants/app_constants.dart';

QueryExecutor openConnection({String? dbName}) {
  return DatabaseConnection.delayed(Future.sync(() async {
    try {
      final result = await WasmDatabase.open(
        databaseName: dbName ?? AppConstants.databaseName,
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
      );
      return result.resolvedExecutor;
    } catch (e, stack) {
      debugPrint('[Drift Web] Lỗi khi mở WasmDatabase: $e\n$stack');
      rethrow;
    }
  }));
}
