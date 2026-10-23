import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/library_sync.dart';
import '../../tagging/data/tag_service.dart';
import '../domain/models/document_model.dart';

/// Service thao tác bảng "Documents" + Supabase Storage (bucket 'documents').
class DocumentService {
  DocumentService._();
  static final DocumentService instance = DocumentService._();

  SupabaseClient get _db => Supabase.instance.client;
  final _tagService = TagService.instance;

  /// Lấy toàn bộ tài liệu (mới nhất trước), đã gắn sẵn tag.
  Future<List<DocumentModel>> fetchDocuments() async {
    final rows = await _db
        .from('Documents')
        .select()
        .order('created_at', ascending: false);
    final ids = rows.map<String>((r) => r['id'] as String).toList();
    final tagsByDoc = await _tagService.fetchTagsForDocuments(ids);
    return rows
        .map<DocumentModel>(
            (r) => DocumentModel.fromMap(r, tags: tagsByDoc[r['id']] ?? []))
        .toList();
  }

  Future<void> createDocument({
    required String ownerId,
    required String ownerEmail,
    required String title,
    required String author,
    required String category,
    required String description,
    required String fileUrl,
    required String fileName,
    required List<String> tagNames,
  }) async {
    final row = await _db.from('Documents').insert({
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'title': title,
      'author': author,
      'category': category,
      'description': description,
      'file_url': fileUrl,
      'file_name': fileName,
    }).select().single();
    final tags = await _tagService.ensureTags(tagNames);
    await _tagService.setDocumentTags(row['id'] as String, tags);
    LibrarySync.instance.notifyChanged();
  }

  Future<void> updateDocument({
    required String documentId,
    required String title,
    required String author,
    required String category,
    required String description,
    required String fileUrl,
    required String fileName,
    required List<String> tagNames,
  }) async {
    await _db.from('Documents').update({
      'title': title,
      'author': author,
      'category': category,
      'description': description,
      'file_url': fileUrl,
      'file_name': fileName,
    }).eq('id', documentId);
    final tags = await _tagService.ensureTags(tagNames);
    await _tagService.setDocumentTags(documentId, tags);
    LibrarySync.instance.notifyChanged();
  }

  Future<void> deleteDocument(String documentId) async {
    await _db.from('Documents').delete().eq('id', documentId);
    LibrarySync.instance.notifyChanged();
  }

  /// Upload file lên bucket 'documents', trả về public URL.
  Future<String> uploadFile(Uint8List bytes, String fileName) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _db.storage.from('documents').uploadBinary(path, bytes);
    return _db.storage.from('documents').getPublicUrl(path);
  }
}
