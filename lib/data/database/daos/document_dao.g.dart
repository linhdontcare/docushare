// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_dao.dart';

// ignore_for_file: type=lint
mixin _$DocumentDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTableTable get categoriesTable => attachedDatabase.categoriesTable;
  $DocumentsTableTable get documentsTable => attachedDatabase.documentsTable;
  DocumentDaoManager get managers => DocumentDaoManager(this);
}

class DocumentDaoManager {
  final _$DocumentDaoMixin _db;
  DocumentDaoManager(this._db);
  $$CategoriesTableTableTableManager get categoriesTable =>
      $$CategoriesTableTableTableManager(
        _db.attachedDatabase,
        _db.categoriesTable,
      );
  $$DocumentsTableTableTableManager get documentsTable =>
      $$DocumentsTableTableTableManager(
        _db.attachedDatabase,
        _db.documentsTable,
      );
}
