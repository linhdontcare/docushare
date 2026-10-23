// ==============================================================================
// CORE LAYER: Database Connection - Native (Android, iOS, Desktop)
// Mở kết nối SQLite bất đồng bộ và hỗ trợ xử lý trên background isolate
// ==============================================================================

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../constants/app_constants.dart';

QueryExecutor openConnection({String? dbName}) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, '${dbName ?? AppConstants.databaseName}.sqlite'));

    return NativeDatabase.createInBackground(
      file,
      logStatements: false,
    );
  });
}
