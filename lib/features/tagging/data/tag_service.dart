import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/library_sync.dart';
import '../../documents/domain/models/document_model.dart';
import '../domain/models/tag_model.dart';

/// Service thao tác bảng "Tags" + "DocumentTags" trên Supabase.
/// Module Documents dùng chung service này để gắn tag cho tài liệu.
class TagService {
  TagService._();
  static final TagService instance = TagService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ------------------------------------------------------------ ĐỌC TAG --
  /// Lấy mọi tag kèm số tài liệu đang gắn tag đó.
  Future<List<TagModel>> fetchTagsWithCounts() async {
    final tagRows = await _db.from('Tags').select().order('name');
    final linkRows = await _db.from('DocumentTags').select('tag_id');
    final counts = <String, int>{};
    for (final r in linkRows) {
      final id = r['tag_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return tagRows
        .map<TagModel>(
            (r) => TagModel.fromMap(r).copyWith(documentCount: counts[r['id']] ?? 0))
        .toList();
  }

  /// Danh sách tài liệu ĐẦY ĐỦ đang gắn 1 tag (để xem chi tiết).
  Future<List<DocumentModel>> fetchDocumentsWithTag(String tagId) async {
    final links = await _db
        .from('DocumentTags')
        .select('document_id')
        .eq('tag_id', tagId);
    final ids = links.map<String>((r) => r['document_id'] as String).toList();
    if (ids.isEmpty) return [];
    final rows = await _db
        .from('Documents')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    final tagsByDoc = await fetchTagsForDocuments(ids);
    return rows
        .map<DocumentModel>(
            (r) => DocumentModel.fromMap(r, tags: tagsByDoc[r['id']] ?? []))
        .toList();
  }

  // ----------------------------------------------------------- GHI TAG --
  Future<TagModel> createTag(String rawName) async {
    final name = _normalize(rawName);
    final row = await _db.from('Tags').insert({'name': name}).select().single();
    LibrarySync.instance.notifyChanged();
    return TagModel.fromMap(row);
  }

  Future<void> renameTag(String tagId, String rawName) async {
    final name = _normalize(rawName);
    await _db.from('Tags').update({'name': name}).eq('id', tagId);
    LibrarySync.instance.notifyChanged();
  }

  /// Xóa tag: các dòng nối trong DocumentTags tự xóa theo (ON DELETE CASCADE),
  /// tài liệu vẫn còn nguyên, chỉ mất tag.
  Future<void> deleteTag(String tagId) async {
    await _db.from('Tags').delete().eq('id', tagId);
    LibrarySync.instance.notifyChanged();
  }

  /// Đảm bảo các tag tồn tại (tạo mới nếu chưa có) — dùng khi lưu tài liệu.
  Future<List<TagModel>> ensureTags(List<String> names) async {
    final clean = names.map(_normalize).where((n) => n.isNotEmpty).toSet();
    final result = <TagModel>[];
    for (final name in clean) {
      final row = await _db
          .from('Tags')
          .upsert({'name': name}, onConflict: 'name')
          .select()
          .single();
      result.add(TagModel.fromMap(row));
    }
    return result;
  }

  /// Gán lại toàn bộ tag cho 1 tài liệu (xóa nối cũ, thêm nối mới).
  Future<void> setDocumentTags(String documentId, List<TagModel> tags) async {
    await _db.from('DocumentTags').delete().eq('document_id', documentId);
    for (final tag in tags) {
      await _db.from('DocumentTags').upsert(
        {'document_id': documentId, 'tag_id': tag.id},
        onConflict: 'document_id,tag_id',
      );
    }
  }

  /// Map document_id -> danh sách tag (cho module Documents hiển thị).
  Future<Map<String, List<TagModel>>> fetchTagsForDocuments(
      List<String> docIds) async {
    final map = <String, List<TagModel>>{};
    if (docIds.isEmpty) return map;
    final rows = await _db
        .from('DocumentTags')
        .select('document_id, Tags(id, name)')
        .inFilter('document_id', docIds);
    for (final r in rows) {
      final tagMap = r['Tags'] as Map<String, dynamic>?;
      if (tagMap == null) continue;
      map
          .putIfAbsent(r['document_id'] as String, () => [])
          .add(TagModel.fromMap(tagMap));
    }
    return map;
  }

  String _normalize(String raw) => raw.trim().replaceAll('#', '').trim();
}
