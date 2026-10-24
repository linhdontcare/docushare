// ==============================================================================
// CORE SUPABASE SERVICE: supabase_service.dart
// Đóng gói khởi tạo và quản lý SupabaseClient
// Tích hợp Firebase Third-Party Auth thông qua callback `accessToken`
// Cung cấp hàm đồng bộ hồ sơ người dùng lên `public.users` với log debug toàn diện
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/borrow_request_model.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/document_permission_model.dart';
import '../../domain/models/supabase_document_model.dart';
import '../../domain/models/user_profile_model.dart';
import '../firebase/firebase_service.dart';
import 'supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;
  String? _initializationError;

  bool get isAvailable => _initialized && _initializationError == null;
  bool get isInitialized => _initialized;
  String? get initializationError => _initializationError;

  /// Supabase Client instance (chỉ khả dụng sau khi initialize thành công)
  SupabaseClient? get client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Định dạng thông điệp lỗi PostgREST thành thông báo dễ hiểu, phân loại rõ ràng
  static String formatPostgrestError(PostgrestException error) {
    final code = error.code ?? 'UNKNOWN';
    switch (code) {
      case '42501':
        return 'Lỗi phân quyền RLS (42501): Bạn không có quyền thao tác trên tài liệu này. Hãy kiểm tra trạng thái đăng nhập hoặc quyền sở hữu.';
      case '23502':
        return 'Lỗi dữ liệu (23502): Thiếu trường dữ liệu bắt buộc (ví dụ: ngày hết hạn hoặc mã định danh).';
      case '23503':
        return 'Lỗi toàn vẹn dữ liệu (23503): Người sở hữu (owner_id) không tồn tại trong hệ thống Supabase.';
      case '23505':
        return 'Lỗi trùng lặp (23505): Bạn đã có một yêu cầu mượn đang chờ duyệt hoặc tài liệu này đã tồn tại.';
      case '22P02':
        return 'Lỗi cú pháp định dạng (22P02): Mã định danh (ID) hoặc owner_id không phải định dạng UUID hợp lệ.';
      default:
        final hint = error.hint != null ? ' (Gợi ý: ${error.hint})' : '';
        return 'Lỗi Supabase [$code]: ${error.message}$hint';
    }
  }

  /// Trích xuất danh sách tag an toàn từ dữ liệu Supabase (hỗ trợ cả JSON array, PostgreSQL array string, `List<dynamic>`)
  static List<String> parseTagsList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().replaceAll('#', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      var str = raw.trim();
      if (str.startsWith('{') && str.endsWith('}')) {
        str = str.substring(1, str.length - 1);
      }
      if (str.isEmpty) return const [];
      return str
          .split(',')
          .map((e) => e.replaceAll('"', '').replaceAll('#', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Tra cứu UUID trong `public.users` của người dùng hiện tại đang đăng nhập qua Firebase
  Future<String?> resolveOwnerId() async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng: ${_initializationError ?? 'Chưa khởi tạo.'}');
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    try {
      final row = await client
          .from('users')
          .select('id')
          .eq('firebase_uid', firebaseUser.uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      if (row != null && row['id'] != null) {
        return row['id'] as String;
      }

      // Tự động đồng bộ nếu chưa có bản ghi người dùng trên Supabase
      final synced = await syncUser(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
      ).timeout(const Duration(seconds: 15));
      return synced.id;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi tra cứu/đồng bộ owner_id từ public.users: $e');
      rethrow;
    }
  }

  /// Thêm mới metadata tài liệu vào bảng `public.documents` với RLS
  /// Nếu bản ghi đã tồn tại (retry hoặc trùng lặp), tự động chuyển sang cập nhật an toàn
  Future<SupabaseDocumentModel> insertDocumentMetadata(
    SupabaseDocumentModel document,
  ) async {
    final client = this.client;
    if (client == null) {
      throw StateError(
        'Supabase client chưa sẵn sàng: ${_initializationError ?? 'Chưa khởi tạo.'}',
      );
    }

    final payload = document.toJsonForInsert();
    debugPrint('[SupabaseService] Đang INSERT metadata tài liệu vào public.documents: ID=${document.id}, Title="${document.title}"');

    try {
      final response = await client
          .from('documents')
          .insert(payload)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Quá thời gian lưu metadata vào Supabase Database (Timeout 30s).',
            ),
          );

      debugPrint('[SupabaseService] => INSERT metadata tài liệu thành công: ${document.id}');
      return SupabaseDocumentModel.fromJson(response);
    } on PostgrestException catch (pgError) {
      // Trường hợp lỗi 23505: bản ghi đã tồn tại (retry an toàn) -> cập nhật thay vì lỗi
      if (pgError.code == '23505') {
        debugPrint('[SupabaseService] Tài liệu đã tồn tại trong public.documents (23505), chuyển sang cập nhật an toàn...');
        return updateDocumentMetadata(
          id: document.id,
          data: document.toJsonForUpdate(),
        );
      }
      final formattedMsg = formatPostgrestError(pgError);
      debugPrint('[SupabaseService] !!! LỖI POSTGREST KHI INSERT DOCUMENT: $formattedMsg');
      throw StateError(formattedMsg);
    } catch (e) {
      if (e is TimeoutException) rethrow;
      if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
        debugPrint('[SupabaseService] Lỗi kết nối mạng khi INSERT tài liệu: $e');
        throw StateError('Lỗi kết nối mạng: Không thể liên lạc tới máy chủ Supabase. Vui lòng kiểm tra Internet.');
      }
      debugPrint('[SupabaseService] Lỗi không xác định khi INSERT tài liệu: $e');
      rethrow;
    }
  }

  /// Cập nhật metadata tài liệu trên bảng `public.documents`
  /// Chỉ gửi đúng 4 trường được phép sửa (title, description, subject, category_id)
  /// TUYỆT ĐỐI không gửi owner_id, id, created_at, updated_at để tuân thủ trigger eduvault_guard_documents
  Future<SupabaseDocumentModel> updateDocumentMetadata({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng.');
    }

    // Lọc an toàn chỉ lấy các trường metadata hợp lệ
    // TUYỆT ĐỐI không cho phép 'id', 'owner_id', 'created_at', 'updated_at' để tuân thủ trigger
    final sanitizedPayload = <String, dynamic>{};
    if (data.containsKey('title') && data['title'] != null) {
      sanitizedPayload['title'] = data['title'];
    }
    if (data.containsKey('description')) {
      sanitizedPayload['description'] = data['description'];
    }
    if (data.containsKey('subject')) {
      sanitizedPayload['subject'] = data['subject'];
    }
    if (data.containsKey('category_id') && data['category_id'] != null) {
      sanitizedPayload['category_id'] = data['category_id'];
    }
    // Hỗ trợ cập nhật vị trí vật lý và bản đồ (Location & Coordinates)
    if (data.containsKey('location_name')) {
      sanitizedPayload['location_name'] = data['location_name'];
    }
    if (data.containsKey('building')) {
      sanitizedPayload['building'] = data['building'];
    }
    if (data.containsKey('floor')) {
      sanitizedPayload['floor'] = data['floor'];
    }
    if (data.containsKey('shelf')) {
      sanitizedPayload['shelf'] = data['shelf'];
    }
    if (data.containsKey('physical_location')) {
      sanitizedPayload['physical_location'] = data['physical_location'];
    }
    if (data.containsKey('latitude')) {
      sanitizedPayload['latitude'] = data['latitude'];
    }
    if (data.containsKey('longitude')) {
      sanitizedPayload['longitude'] = data['longitude'];
    }
    if (data.containsKey('location_notes')) {
      sanitizedPayload['location_notes'] = data['location_notes'];
    }
    if (data.containsKey('is_available_for_borrow')) {
      sanitizedPayload['is_available_for_borrow'] = data['is_available_for_borrow'];
    }
    if (data.containsKey('is_discoverable')) {
      sanitizedPayload['is_discoverable'] = data['is_discoverable'];
    }
    if (data.containsKey('is_borrowable')) {
      sanitizedPayload['is_borrowable'] = data['is_borrowable'];
    }
    // Hỗ trợ cập nhật danh sách thẻ nhãn (Tags / Hashtags)
    if (data.containsKey('tags_cache')) {
      final t = data['tags_cache'];
      if (t == null) {
        sanitizedPayload['tags_cache'] = <String>[];
      } else if (t is List) {
        sanitizedPayload['tags_cache'] = t
            .map((e) => e.toString().replaceAll('#', '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        sanitizedPayload['tags_cache'] = parseTagsList(t);
      }
    } else if (data.containsKey('tags')) {
      final t = data['tags'];
      if (t == null) {
        sanitizedPayload['tags_cache'] = <String>[];
      } else if (t is List) {
        sanitizedPayload['tags_cache'] = t
            .map((e) => e.toString().replaceAll('#', '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        sanitizedPayload['tags_cache'] = parseTagsList(t);
      }
    }
    // Hỗ trợ trường hợp Owner chủ động đổi file mới
    if (data.containsKey('file_name') && data['file_name'] != null) {
      sanitizedPayload['file_name'] = data['file_name'];
    }
    if (data.containsKey('file_type') && data['file_type'] != null) {
      sanitizedPayload['file_type'] = data['file_type'];
    }
    if (data.containsKey('file_size') && data['file_size'] != null) {
      sanitizedPayload['file_size'] = data['file_size'];
    }
    if (data.containsKey('storage_path') && data['storage_path'] != null) {
      sanitizedPayload['storage_path'] = data['storage_path'];
    }

    if (sanitizedPayload.isEmpty) {
      debugPrint('[SupabaseService] Không có trường metadata nào cần cập nhật cho ID: $id');
      final existing = await getDocumentMetadata(id);
      if (existing != null) return existing;
      throw StateError('Không tìm thấy tài liệu với ID: $id');
    }

    debugPrint('[SupabaseService] Đang UPDATE metadata tài liệu: ID=$id, Payload=$sanitizedPayload');

    try {
      final response = await client
          .from('documents')
          .update(sanitizedPayload)
          .eq('id', id)
          .select()
          .single()
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException(
              'Quá thời gian cập nhật metadata trên Supabase Database (Timeout 30s).',
            ),
          );

      debugPrint('[SupabaseService] => UPDATE metadata tài liệu thành công: $id');
      return SupabaseDocumentModel.fromJson(response);
    } on PostgrestException catch (pgError) {
      final formattedMsg = formatPostgrestError(pgError);
      debugPrint('[SupabaseService] !!! LỖI POSTGREST KHI UPDATE DOCUMENT: $formattedMsg');
      throw StateError(formattedMsg);
    } catch (e) {
      if (e is TimeoutException) rethrow;
      if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
        debugPrint('[SupabaseService] Lỗi kết nối mạng khi UPDATE tài liệu: $e');
        throw StateError('Lỗi kết nối mạng: Không thể gửi dữ liệu tới Supabase.');
      }
      debugPrint('[SupabaseService] Lỗi không xác định khi UPDATE tài liệu: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SUPABASE STORAGE (LƯU TRỮ TỆP MIỄN PHÍ - KHÔNG CẦN THẺ / GÓI BLAZE)
  // ============================================================================

  static const String storageBucketName = 'documents';

  /// Client lưu trữ độc lập sử dụng Supabase anonKey (HS256)
  /// Tránh lỗi xung đột thuật toán "alg" (RS256) từ Firebase Auth ID Token
  SupabaseStorageClient get _storageClient {
    return SupabaseStorageClient(
      '${SupabaseConfig.projectUrl}/storage/v1',
      {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      },
    );
  }

  /// Upload tệp lên Supabase Storage bucket 'documents' với dynamic timeout theo dung lượng
  Future<String> uploadDocumentFile({
    required String path,
    Uint8List? fileBytes,
    File? file,
    String? contentType,
  }) async {
    final storage = _storageClient.from(storageBucketName);
    final options = FileOptions(
      contentType: contentType,
      upsert: true,
    );

    final byteCount = fileBytes?.length ?? (file != null ? (await file.length()) : 0);
    // Timeout upload tính linh hoạt theo dung lượng: tối thiểu 30s + 1s cho mỗi 50KB
    final timeoutSeconds = math.max(30, 20 + (byteCount ~/ (50 * 1024)));
    final uploadTimeout = Duration(seconds: timeoutSeconds);

    debugPrint('[Supabase Storage] Đang upload tệp vào bucket "$storageBucketName", path: $path ($byteCount bytes, timeout: ${timeoutSeconds}s)...');
    try {
      if (fileBytes != null) {
        await storage.uploadBinary(path, fileBytes, fileOptions: options).timeout(
          uploadTimeout,
          onTimeout: () => throw TimeoutException('Quá thời gian tải tệp lên Supabase Storage (${timeoutSeconds}s).'),
        );
      } else if (file != null) {
        final bytes = await file.readAsBytes().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Quá thời gian đọc tệp từ thiết bị (15s).'),
        );
        await storage.uploadBinary(path, bytes, fileOptions: options).timeout(
          uploadTimeout,
          onTimeout: () => throw TimeoutException('Quá thời gian tải tệp lên Supabase Storage (${timeoutSeconds}s).'),
        );
      } else {
        throw ArgumentError('Cần cung cấp file hoặc fileBytes để tải lên.');
      }
    } on StorageException catch (storageErr) {
      debugPrint('[Supabase Storage] StorageException: statusCode=${storageErr.statusCode}, error=${storageErr.error}, message=${storageErr.message}');
      if (storageErr.statusCode == '403') {
        throw StateError('Lỗi phân quyền Supabase Storage (403 Unauthorized). Hãy kiểm tra bucket "$storageBucketName" đã được đặt Public hoặc có Storage Policy phù hợp.');
      } else if (storageErr.statusCode == '404' || storageErr.message.toLowerCase().contains('bucket not found')) {
        throw StateError('Bucket "$storageBucketName" không tồn tại trên Supabase Storage.');
      } else if (storageErr.statusCode == '400') {
        throw StateError('Yêu cầu không hợp lệ tới Supabase Storage (400): ${storageErr.message}');
      }
      rethrow;
    } catch (e) {
      if (e is TimeoutException) rethrow;
      if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
        throw StateError('Lỗi kết nối mạng: Không thể liên lạc tới máy chủ Supabase Storage.');
      }
      rethrow;
    }

    debugPrint('[Supabase Storage] => Upload hoàn tất thành công: $path');
    return path;
  }

  /// Lấy Public URL để xem hoặc tải tệp trực tiếp từ Supabase Storage
  String getPublicUrl(String storagePath) {
    return _storageClient.from(storageBucketName).getPublicUrl(storagePath);
  }

  /// Tải tệp từ Supabase Storage về File tạm cục bộ
  Future<dynamic> downloadToTemporaryFile({
    required String storagePath,
    required String fileName,
  }) async {
    final bytes = await _storageClient.from(storageBucketName).download(storagePath);
    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes);
      return tempFile;
    }
    return bytes;
  }

  /// Xóa tệp khỏi Supabase Storage
  Future<void> deleteStorageFile(String storagePath) async {
    try {
      await _storageClient
          .from(storageBucketName)
          .remove([storagePath])
          .timeout(const Duration(seconds: 15));
      debugPrint('[Supabase Storage] Đã xóa tệp: $storagePath');
    } catch (e) {
      debugPrint('[Supabase Storage] Lỗi xóa tệp: $e');
    }
  }

  /// Xóa metadata tài liệu khỏi bảng `public.documents`
  /// Policy `documents_delete` chỉ cho phép Owner thực thi
  Future<void> deleteDocumentMetadata(String documentId) async {
    final client = this.client;
    if (client == null) {
      debugPrint('[DELETE] Supabase failure: Supabase client chưa sẵn sàng.');
      throw StateError('Supabase client chưa sẵn sàng.');
    }

    debugPrint('[DELETE] Supabase: Đang xóa metadata tài liệu ID=$documentId');

    try {
      final response = await client
          .from('documents')
          .delete()
          .eq('id', documentId)
          .select()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Quá thời gian xóa tài liệu trên Supabase (15s).'),
          );

      final deletedRows = response as List<dynamic>? ?? [];
      if (deletedRows.isEmpty) {
        // Kiểm tra xem tài liệu có còn tồn tại không để phát hiện RLS chặn xóa
        final stillExists = await documentMetadataExists(documentId);
        if (stillExists) {
          debugPrint('[DELETE] Supabase failure: Tài liệu vẫn tồn tại nhưng lệnh DELETE trả về 0 rows (bị từ chối bởi RLS policies)');
          throw StateError('Không thể xóa tài liệu trên Supabase: Bạn không có quyền Owner đối với tài liệu này (RLS Denied).');
        }
        debugPrint('[DELETE] Supabase success: Bản ghi không còn tồn tại trên public.documents (đã xóa)');
      } else {
        debugPrint('[DELETE] Supabase success: Đã xóa thành công bản ghi ID=$documentId (${deletedRows.length} rows)');
      }
    } on PostgrestException catch (pgError) {
      final formattedMsg = formatPostgrestError(pgError);
      debugPrint('[DELETE] Supabase failure: PostgrestException: $formattedMsg');
      throw StateError(formattedMsg);
    } catch (e) {
      if (e is TimeoutException) rethrow;
      if (e.toString().contains('SocketException') || e.toString().contains('ClientException')) {
        debugPrint('[DELETE] Supabase failure: Lỗi kết nối mạng: $e');
        throw StateError('Lỗi kết nối mạng: Không thể xóa tài liệu trên Supabase.');
      }
      debugPrint('[DELETE] Supabase failure: $e');
      rethrow;
    }
  }

  /// Lấy chi tiết metadata một tài liệu từ bảng `public.documents`
  Future<SupabaseDocumentModel?> getDocumentMetadata(String documentId) async {
    final client = this.client;
    if (client == null) return null;

    try {
      final response = await client
          .from('documents')
          .select()
          .eq('id', documentId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

      if (response == null) return null;
      return SupabaseDocumentModel.fromJson(response);
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi lấy tài liệu $documentId: $e');
      return null;
    }
  }

  /// Kiểm tra xem metadata tài liệu đã tồn tại trong `public.documents` hay chưa
  Future<bool> documentMetadataExists(String documentId) async {
    final doc = await getDocumentMetadata(documentId);
    return doc != null;
  }

  // ============================================================================
  // CÁC HÀM QUẢN LÝ PHÂN QUYỀN VÀ CHIA SẺ TÀI LIỆU (PUBLIC.PERMISSIONS)
  // ============================================================================

  /// Tra cứu người dùng trong `public.users` theo email
  Future<UserProfileModel?> findUserByEmail(String email) async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng.');
    }
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      final res = await client
          .from('users')
          .select()
          .eq('email', cleanEmail)
          .maybeSingle();

      if (res == null) return null;
      return UserProfileModel.fromJson(res);
    } on PostgrestException catch (pgError) {
      debugPrint('[SupabaseService] Lỗi khi tìm user bằng email: ${formatPostgrestError(pgError)}');
      return null;
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tìm user bằng email: $e');
      return null;
    }
  }

  /// Lấy danh sách các quyền được chia sẻ của một tài liệu (Chỉ Owner mới có quyền xem qua RLS)
  Future<List<DocumentPermissionModel>> getDocumentPermissions(String documentId) async {
    final client = this.client;
    if (client == null) return [];
    final docUuid = SupabaseDocumentModel.toValidUuid(documentId);

    try {
      // 1. Thử truy vấn join với bảng users
      try {
        final res = await client
            .from('permissions')
            .select('*, users!permissions_user_id_fkey(id, email, display_name, photo_url)')
            .eq('document_id', docUuid)
            .order('created_at', ascending: false);

        final list = (res as List<dynamic>)
            .map((item) => DocumentPermissionModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return list;
      } catch (joinErr) {
        debugPrint('[SupabaseService] Join permissions với users chưa thành công ($joinErr), chuyển sang fallback 2 bước...');
      }

      // 2. Fallback: Lấy permissions trước, sau đó tra cứu danh sách users
      final permRows = await client
          .from('permissions')
          .select()
          .eq('document_id', docUuid)
          .order('created_at', ascending: false);

      final permList = (permRows as List<dynamic>)
          .map((item) => DocumentPermissionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (permList.isEmpty) return [];

      final userIds = permList.map((p) => p.userId).toSet().toList();
      final userRows = await client
          .from('users')
          .select('id, email, display_name, photo_url')
          .inFilter('id', userIds);

      final userMap = <String, Map<String, dynamic>>{};
      for (final u in userRows as List<dynamic>) {
        final m = u as Map<String, dynamic>;
        userMap[m['id'] as String] = m;
      }

      return permList.map((p) {
        final u = userMap[p.userId];
        return p.copyWith(
          userEmail: u?['email'] as String?,
          userDisplayName: u?['display_name'] as String?,
          userPhotoUrl: u?['photo_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (pgError) {
      debugPrint('[SupabaseService] Lỗi khi lấy permissions: ${formatPostgrestError(pgError)}');
      return [];
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi lấy permissions: $e');
      return [];
    }
  }

  /// Cấp quyền hoặc cập nhật quyền chia sẻ tài liệu cho người dùng khác
  /// Sử dụng upsert onConflict: 'document_id, user_id'
  Future<DocumentPermissionModel> shareDocument({
    required String documentId,
    required String recipientUserId,
    required String permissionType,
  }) async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng.');
    }
    final docUuid = SupabaseDocumentModel.toValidUuid(documentId);
    final role = permissionType.trim().toLowerCase();
    if (role != 'viewer' && role != 'editor') {
      throw ArgumentError('Quyền chỉ có thể là viewer hoặc editor.');
    }

    debugPrint('[SupabaseService] [SHARE] Đang cấp quyền: doc=$docUuid, recipient=$recipientUserId, role=$role');

    try {
      final payload = {
        'document_id': docUuid,
        'user_id': recipientUserId,
        'permission_type': role,
      };

      final res = await client
          .from('permissions')
          .upsert(payload, onConflict: 'document_id, user_id')
          .select()
          .single();

      debugPrint('[SupabaseService] [SHARE] => Cấp quyền thành công: ${res['id']}');
      return DocumentPermissionModel.fromJson(res);
    } on PostgrestException catch (pgError) {
      final formattedMsg = formatPostgrestError(pgError);
      debugPrint('[SupabaseService] [SHARE] Lỗi PostgrestException: $formattedMsg');
      throw StateError(formattedMsg);
    } catch (e) {
      debugPrint('[SupabaseService] [SHARE] Lỗi không xác định: $e');
      rethrow;
    }
  }

  /// Cập nhật vai trò quyền đã cấp (từ viewer sang editor hoặc ngược lại)
  Future<DocumentPermissionModel> updatePermissionRole({
    required String permissionId,
    required String permissionType,
  }) async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng.');
    }
    final role = permissionType.trim().toLowerCase();
    if (role != 'viewer' && role != 'editor') {
      throw ArgumentError('Quyền chỉ có thể là viewer hoặc editor.');
    }

    try {
      final res = await client
          .from('permissions')
          .update({'permission_type': role})
          .eq('id', permissionId)
          .select()
          .single();

      debugPrint('[SupabaseService] [UPDATE PERMISSION] => Thành công: $permissionId sang $role');
      return DocumentPermissionModel.fromJson(res);
    } on PostgrestException catch (pgError) {
      final formattedMsg = formatPostgrestError(pgError);
      throw StateError(formattedMsg);
    } catch (e) {
      rethrow;
    }
  }

  /// Thu hồi quyền chia sẻ (Xóa bản ghi khỏi bảng public.permissions)
  Future<void> revokeDocumentPermission(String permissionId) async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng.');
    }

    try {
      await client.from('permissions').delete().eq('id', permissionId);
      debugPrint('[SupabaseService] [REVOKE PERMISSION] => Đã thu hồi quyền ID: $permissionId');
    } on PostgrestException catch (pgError) {
      final formattedMsg = formatPostgrestError(pgError);
      throw StateError(formattedMsg);
    } catch (e) {
      rethrow;
    }
  }

  /// Tải danh sách tài liệu thuộc sở hữu của người dùng hiện tại từ bảng `public.documents`
  Future<List<DocumentModel>> fetchUserDocumentsForCurrentUser() async {
    final client = this.client;
    if (client == null) {
      throw StateError('Supabase client chưa sẵn sàng: ${_initializationError ?? 'Chưa khởi tạo.'}');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    debugPrint('[SupabaseService] Bắt đầu tải danh sách tài liệu cá nhân từ public.documents...');

    try {
      final ownerId = await resolveOwnerId();
      if (ownerId == null || ownerId.trim().isEmpty) {
        debugPrint('[SupabaseService] Chưa có owner_id hợp lệ cho tài khoản hiện tại trong public.users, trả về danh sách rỗng.');
        return [];
      }

      final query = client.from('documents').select().eq('owner_id', ownerId);

      final rows = await query.order('created_at', ascending: false).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Quá thời gian tải danh sách tài liệu từ Supabase (20s).'),
      );

      final List<DocumentModel> result = [];
      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<String, dynamic>);
        result.add(DocumentModel(
          id: m['id'] as String,
          title: m['title'] as String? ?? '',
          subject: m['subject'] as String? ?? '',
          categoryId: m['category_id'] as String? ?? 'all',
          filePathOrUrl: m['storage_path'] as String?,
          notes: m['description'] as String?,
          tags: parseTagsList(m['tags_cache'] ?? m['tags']),
          locationName: m['location_name'] as String?,
          building: m['building'] as String?,
          floor: m['floor'] as String?,
          shelf: m['shelf'] as String?,
          physicalLocation: m['physical_location'] as String?,
          latitude: (m['latitude'] as num?)?.toDouble(),
          longitude: (m['longitude'] as num?)?.toDouble(),
          locationNotes: m['location_notes'] as String?,
          isAvailableForBorrow: m['is_available_for_borrow'] as bool? ?? (m['is_borrowable'] as bool? ?? false),
          isDiscoverable: m['is_discoverable'] as bool? ?? false,
          isBorrowable: m['is_borrowable'] as bool? ?? (m['is_available_for_borrow'] as bool? ?? false),
          createdDate: m['created_at'] != null
              ? DateTime.tryParse(m['created_at'] as String) ?? DateTime.now()
              : DateTime.now(),
          updatedDate: m['updated_at'] != null
              ? DateTime.tryParse(m['updated_at'] as String) ?? DateTime.now()
              : DateTime.now(),
          userPermissionRole: 'owner',
          ownerEmail: user.email,
          ownerName: user.displayName,
        ));
      }

      debugPrint('[SupabaseService] => Đã tải thành công ${result.length} tài liệu từ public.documents');
      return result;
    } on PostgrestException catch (pgError) {
      final msg = formatPostgrestError(pgError);
      debugPrint('[SupabaseService] Lỗi PostgREST khi tải tài liệu người dùng: $msg');
      throw StateError(msg);
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tải tài liệu người dùng từ Supabase: $e');
      rethrow;
    }
  }

  /// Lấy danh sách các tài liệu được chia sẻ cho người dùng hiện tại
  /// (Khi người dùng hiện tại là recipient trong bảng public.permissions)
  Future<List<Map<String, dynamic>>> fetchSharedDocumentsForCurrentUser() async {
    final client = this.client;
    if (client == null) return [];

    final myUserId = await resolveOwnerId();
    if (myUserId == null) {
      debugPrint('[SupabaseService] Chưa xác định được UUID trong public.users của người dùng hiện tại.');
      return [];
    }

    try {
      // 1. Lấy tất cả permissions của người dùng hiện tại
      final permRows = await client
          .from('permissions')
          .select('id, document_id, permission_type, created_at')
          .eq('user_id', myUserId);

      final permList = permRows as List<dynamic>;
      if (permList.isEmpty) return [];

      final docIds = permList.map((p) => p['document_id'] as String).toList();
      final permMap = <String, Map<String, dynamic>>{};
      for (final p in permList) {
        permMap[p['document_id'] as String] = p as Map<String, dynamic>;
      }

      // 2. Lấy danh sách tài liệu tương ứng từ public.documents (RLS documents_select cho phép vì has_permission)
      final docRows = await client
          .from('documents')
          .select()
          .inFilter('id', docIds)
          .order('created_at', ascending: false);

      final docList = docRows as List<dynamic>;
      if (docList.isEmpty) return [];

      // 3. Lấy thông tin owner (email, display_name) của các tài liệu này
      final ownerIds = docList.map((d) => d['owner_id'] as String).toSet().toList();
      final ownerRows = await client
          .from('users')
          .select('id, email, display_name, photo_url')
          .inFilter('id', ownerIds);

      final ownerMap = <String, Map<String, dynamic>>{};
      for (final o in ownerRows as List<dynamic>) {
        final m = o as Map<String, dynamic>;
        ownerMap[m['id'] as String] = m;
      }

      // 4. Kết hợp dữ liệu thành danh sách hoàn chỉnh
      final result = <Map<String, dynamic>>[];
      for (final doc in docList) {
        final docMap = Map<String, dynamic>.from(doc as Map<String, dynamic>);
        final docId = docMap['id'] as String;
        final perm = permMap[docId];
        final ownerId = docMap['owner_id'] as String;
        final owner = ownerMap[ownerId];

        docMap['user_permission_role'] = perm?['permission_type'] ?? 'viewer';
        docMap['owner_email'] = owner?['email'];
        docMap['owner_name'] = owner?['display_name'];
        result.add(docMap);
      }

      return result;
    } on PostgrestException catch (pgError) {
      debugPrint('[SupabaseService] Lỗi khi tải shared documents: ${formatPostgrestError(pgError)}');
      return [];
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tải shared documents: $e');
      return [];
    }
  }

  /// Khởi tạo Supabase SDK với callback lấy accessToken từ Firebase ID Token.
  Future<void> initialize({
    String? url,
    String? publishableKey,
    String? anonKey,
    Future<String?> Function()? accessToken,
  }) async {
    if (_initialized) {
      debugPrint('[SupabaseService] Supabase đã được khởi tạo trước đó. Bỏ qua.');
      return;
    }

    final targetUrl = url ?? SupabaseConfig.url;
    final effectiveKey = publishableKey ?? anonKey ?? SupabaseConfig.effectivePublishableKey;

    final isValidConfig = targetUrl.trim().isNotEmpty &&
        targetUrl.trim().startsWith('https://') &&
        effectiveKey.trim().isNotEmpty;

    if (!isValidConfig) {
      _initializationError = 'Thông tin Supabase URL hoặc Publishable Key chưa được cấu hình hợp lệ.';
      debugPrint('[SupabaseService] Lưu ý: $_initializationError');
      return;
    }

    try {
      debugPrint('[SupabaseService] Đang khởi tạo Supabase SDK với URL: $targetUrl');

      await Supabase.initialize(
        url: targetUrl.trim(),
        publishableKey: effectiveKey.trim(),
        // Cơ chế Third-Party Auth: Mỗi khi Supabase Client gửi request PostgREST,
        // callback accessToken sẽ tự động được SDK gọi để lấy Firebase ID Token mới nhất.
        accessToken: accessToken ?? () async {
          try {
            final firebaseUser = FirebaseAuth.instance.currentUser;
            if (firebaseUser == null) {
              return null;
            }
            return await firebaseUser.getIdToken().timeout(const Duration(seconds: 10));
          } catch (e) {
            debugPrint('[SupabaseService] accessToken callback: Lỗi khi lấy Firebase ID Token: $e');
            return null;
          }
        },
      );

      _initialized = true;
      _initializationError = null;
      debugPrint('[SupabaseService] Khởi tạo Supabase SDK thành công với Third-Party Auth callback.');
    } catch (e) {
      _initializationError = e.toString();
      debugPrint('[SupabaseService] Khởi tạo Supabase thất bại: $e');
    }
  }

  /// Đồng bộ người dùng Firebase Authentication vào bảng `public.users` trên Supabase.
  /// Bổ sung log debug chi tiết từng bước phục vụ kiểm tra và chẩn đoán.
  Future<UserProfileModel> syncUser({
    required String firebaseUid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    final client = this.client;
    if (client == null) {
      final errorMsg = 'Supabase client chưa sẵn sàng: ${_initializationError ?? 'Chưa khởi tạo.'}';
      debugPrint('[SupabaseService] $errorMsg');
      throw StateError(errorMsg);
    }

    debugPrint('------------------------------------------------------------');
    debugPrint('[SupabaseService] [BƯỚC 1/3] Bắt đầu đồng bộ người dùng sang Supabase public.users');
    debugPrint('[SupabaseService]   * Firebase UID: $firebaseUid');
    debugPrint('[SupabaseService]   * Email: $email');
    debugPrint('[SupabaseService]   * Tên hiển thị: ${displayName ?? '(trống)'}');

    // Đảm bảo tài khoản có custom claim role: "authenticated" trước khi gửi PostgREST
    try {
      final curUser = FirebaseAuth.instance.currentUser;
      if (curUser != null) {
        await FirebaseService.instance.ensureSupabaseAuthenticatedRole(curUser);
        final token = await curUser.getIdToken().timeout(const Duration(seconds: 10));
        final claims = FirebaseService.decodeTokenPayload(token);
        if (claims != null) {
          debugPrint('[SupabaseService] [XÁC NHẬN AN TOÀN JWT CLAIMS]');
          debugPrint('  * Issuer (iss): ${claims['iss']}');
          debugPrint('  * Audience (aud): ${claims['aud']}');
          debugPrint('  * Subject (sub / UID): ${claims['sub']}');
          debugPrint('  * Email (email): ${claims['email']}');
          debugPrint('  * Role claim: ${claims['role']}');
        }
      }
    } catch (tokenDiagErr) {
      debugPrint('[SupabaseService] Không thể chẩn đoán claims trước khi gửi: $tokenDiagErr');
    }

    // Chuẩn bị payload đúng cấu trúc bảng public.users:
    // id: tự sinh qua DEFAULT gen_random_uuid() hoặc giữ nguyên qua Trigger khi conflict
    final payload = <String, dynamic>{
      'firebase_uid': firebaseUid,
      'email': email.trim().toLowerCase(),
      'display_name': displayName,
      'photo_url': photoUrl,
    };

    try {
      debugPrint('[SupabaseService] [BƯỚC 2/3] Gửi PostgREST upsert (onConflict: firebase_uid)...');

      final response = await client
          .from('users')
          .upsert(payload, onConflict: 'firebase_uid')
          .select()
          .single()
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException(
              'Quá thời gian đồng bộ hồ sơ người dùng lên Supabase (20s).',
            ),
          );

      final profile = UserProfileModel.fromJson(response);
      debugPrint('[SupabaseService]   => Upsert thành công! Supabase User UUID: ${profile.id}');

      debugPrint('[SupabaseService] [BƯỚC 3/3] Đọc lại hồ sơ từ Supabase để xác nhận JWT và RLS hoạt động...');
      final verifiedProfile = await client
          .from('users')
          .select()
          .eq('firebase_uid', firebaseUid)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => null,
          );

      if (verifiedProfile != null) {
        debugPrint(
          '[SupabaseService]   => XÁC THỰC RLS & JWT HOÀN TẤT! '
          'Hồ sơ của chính người dùng đã được đọc thành công: ${verifiedProfile['email']} '
          '(UUID: ${verifiedProfile['id']})',
        );
      } else {
        debugPrint('[SupabaseService]   => Cảnh báo: Upsert thành công nhưng query SELECT trả về null.');
      }
      debugPrint('------------------------------------------------------------');

      return profile;
    } on PostgrestException catch (pgError) {
      debugPrint('------------------------------------------------------------');
      debugPrint('[SupabaseService] !!! LỖI POSTGREST TỪ SUPABASE:');
      debugPrint('[SupabaseService]   * Mã lỗi (Code): ${pgError.code}');
      debugPrint('[SupabaseService]   * Thông điệp (Message): ${pgError.message}');
      debugPrint('[SupabaseService]   * Chi tiết (Details): ${pgError.details}');
      debugPrint('[SupabaseService]   * Gợi ý (Hint): ${pgError.hint}');
      debugPrint('------------------------------------------------------------');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('------------------------------------------------------------');
      debugPrint('[SupabaseService] !!! LỖI KHÔNG XÁC ĐỊNH KHI ĐỒNG BỘ: $e');
      debugPrint('[SupabaseService] StackTrace: $stackTrace');
      debugPrint('------------------------------------------------------------');
      rethrow;
    }
  }

  // ============================================================================
  // NGHIỆP VỤ MƯỢN & TRẢ TÀI LIỆU VÀ KHÁM PHÁ (TH2)
  // ============================================================================

  /// Tải danh sách tài liệu công khai được phép khám phá (is_discoverable = true)
  /// Sử dụng RPC an toàn hoặc truy vấn PostgREST chỉ lấy metadata công khai,
  /// tự động loại trừ tài liệu của chính người đang đăng nhập.
  Future<List<DocumentModel>> fetchDiscoverableDocuments({
    String? search,
    String? subject,
    String? categoryId,
    String? tag,
  }) async {
    final client = this.client;
    if (client == null) return [];

    try {
      // 1. Ưu tiên gọi RPC bảo mật get_discoverable_documents
      try {
        final res = await client.rpc('get_discoverable_documents', params: {
          'p_search': (search != null && search.trim().isNotEmpty) ? search.trim() : null,
          'p_subject': (subject != null && subject.trim().isNotEmpty) ? subject.trim() : null,
          'p_category_id': (categoryId != null && categoryId != 'all') ? categoryId : null,
          'p_tag': (tag != null && tag.trim().isNotEmpty) ? tag.trim() : null,
        });

        if (res is List) {
          return res.map((row) {
            final map = row as Map<String, dynamic>;
            final isBorrow = map['is_borrowable'] as bool? ?? false;
            return DocumentModel(
              id: map['id'] as String? ?? '',
              title: map['title'] as String? ?? '',
              subject: map['subject'] as String? ?? '',
              categoryId: map['category_id'] as String? ?? 'all',
              notes: map['description'] as String?,
              tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              locationName: map['location_name'] as String?,
              building: map['building'] as String?,
              floor: map['floor'] as String?,
              shelf: map['shelf'] as String?,
              ownerEmail: map['owner_email'] as String?,
              ownerName: map['owner_name'] as String?,
              isDiscoverable: true,
              isBorrowable: isBorrow,
              isAvailableForBorrow: isBorrow,
              userPermissionRole: 'viewer',
              createdDate: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
              updatedDate: DateTime.now(),
            );
          }).toList();
        }
      } catch (rpcError) {
        debugPrint('[SupabaseService] RPC get_discoverable_documents fallback: $rpcError');
      }

      // 2. Fallback trực tiếp qua PostgREST nếu RPC chưa được nạp
      var query = client
          .from('documents')
          .select('id, title, description, subject, category_id, is_discoverable, is_borrowable, tags_cache, location_name, building, floor, shelf, physical_location, latitude, longitude, location_notes, created_at, owner:users!owner_id(email, display_name)')
          .eq('is_discoverable', true);

      if (categoryId != null && categoryId != 'all') {
        query = query.eq('category_id', categoryId);
      }
      if (subject != null && subject.trim().isNotEmpty) {
        query = query.ilike('subject', '%${subject.trim()}%');
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('title.ilike.%${search.trim()}%,subject.ilike.%${search.trim()}%,description.ilike.%${search.trim()}%');
      }

      final rows = await query.order('created_at', ascending: false);
      final currentUserId = await resolveOwnerId();

      return (rows as List<dynamic>)
          .where((r) => currentUserId == null || r['owner_id'] != currentUserId)
          .map((r) {
            final map = r as Map<String, dynamic>;
            final ownerMap = map['owner'] as Map<String, dynamic>?;
            final isBorrow = map['is_borrowable'] as bool? ?? false;
            final tagsRaw = map['tags_cache'];
            final tagsList = (tagsRaw is List)
                ? tagsRaw.map((e) => e.toString()).toList()
                : <String>[];
            return DocumentModel(
              id: map['id'] as String? ?? '',
              title: map['title'] as String? ?? '',
              subject: map['subject'] as String? ?? '',
              categoryId: map['category_id'] as String? ?? 'all',
              notes: map['description'] as String?,
              tags: tagsList,
              locationName: map['location_name'] as String?,
              building: map['building'] as String?,
              floor: map['floor'] as String?,
              shelf: map['shelf'] as String?,
              physicalLocation: map['physical_location'] as String?,
              latitude: (map['latitude'] as num?)?.toDouble(),
              longitude: (map['longitude'] as num?)?.toDouble(),
              locationNotes: map['location_notes'] as String?,
              ownerEmail: ownerMap != null ? ownerMap['email'] as String? : null,
              ownerName: ownerMap != null ? ownerMap['display_name'] as String? : null,
              isDiscoverable: true,
              isBorrowable: isBorrow,
              isAvailableForBorrow: isBorrow,
              userPermissionRole: 'viewer',
              createdDate: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
              updatedDate: DateTime.now(),
            );
          })
          .toList();
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tải danh sách khám phá: $e');
      return [];
    }
  }

  /// Lấy thông tin chi tiết đầy đủ của một tài liệu theo ID từ Supabase.
  /// Hỗ trợ cả Owner, người được chia sẻ (Editor/Viewer), và người mượn đang active.
  /// PostgREST RLS policy `documents_select` tự động cho phép đọc nếu có active borrow hoặc permission.
  Future<DocumentModel?> fetchDocumentById(String documentId) async {
    final client = this.client;
    if (client == null) return null;
    try {
      final res = await client
          .from('documents')
          .select('*, owner:users!owner_id(email, display_name)')
          .eq('id', documentId)
          .maybeSingle();

      if (res == null) return null;
      final map = res;
      final ownerMap = map['owner'] as Map<String, dynamic>?;
      final isBorrow = map['is_borrowable'] as bool? ?? false;
      final currentUserId = await resolveOwnerId();
      final isOwner = currentUserId != null && currentUserId == map['owner_id'];

      // Lấy danh sách tags từ tags_cache nếu có
      final tagsRaw = map['tags_cache'];
      List<String> tagsList = [];
      if (tagsRaw is List) {
        tagsList = tagsRaw.map((e) => e.toString()).toList();
      }

      // Xác định chính xác role của current user đối với document này
      String userRole = 'viewer';
      if (isOwner) {
        userRole = 'owner';
      } else if (currentUserId != null) {
        try {
          final permRow = await client
              .from('permissions')
              .select('permission_type')
              .eq('document_id', documentId)
              .eq('user_id', currentUserId)
              .maybeSingle();
          if (permRow != null && permRow['permission_type'] != null) {
            userRole = permRow['permission_type'] as String;
          } else {
            // Kiểm tra xem có phải borrower đang active không
            final nowIso = DateTime.now().toIso8601String();
            final borrowRow = await client
                .from('borrow_requests')
                .select('id')
                .eq('document_id', documentId)
                .eq('borrower_id', currentUserId)
                .eq('status', 'approved')
                .gt('due_at', nowIso)
                .isFilter('returned_at', null)
                .maybeSingle();
            if (borrowRow != null) {
              userRole = 'borrower';
            }
          }
        } catch (_) {}
      }

      return DocumentModel(
        id: map['id'] as String? ?? documentId,
        title: map['title'] as String? ?? '',
        subject: map['subject'] as String? ?? '',
        categoryId: map['category_id'] as String? ?? 'all',
        filePathOrUrl: map['storage_path'] as String?,
        notes: map['description'] as String?,
        tags: tagsList,
        locationName: map['location_name'] as String?,
        building: map['building'] as String?,
        floor: map['floor'] as String?,
        shelf: map['shelf'] as String?,
        physicalLocation: map['physical_location'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        locationNotes: map['location_notes'] as String?,
        isAvailableForBorrow: isBorrow,
        isDiscoverable: map['is_discoverable'] as bool? ?? false,
        isBorrowable: isBorrow,
        userPermissionRole: userRole,
        ownerEmail: ownerMap?['email'] as String?,
        ownerName: ownerMap?['display_name'] as String?,
        createdDate: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
        updatedDate: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) ?? DateTime.now() : DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SupabaseService] fetchDocumentById($documentId) error: $e');
      return null;
    }
  }

  /// Tạo yêu cầu mượn tài liệu mới (Hỗ trợ 1, 3, 7, 14 ngày)
  Future<BorrowRequestModel> createBorrowRequest({
    required String documentId,
    required String documentTitle,
    required String borrowerId,
    required String borrowerEmail,
    String? borrowerName,
    required String ownerId,
    int requestedDays = 7,
    DateTime? dueDate,
    String? message,
    // Tương thích ngược
    String? requesterId,
    String? requesterEmail,
    String? requesterName,
    String? notes,
  }) async {
    final client = this.client;
    final requestId = const Uuid().v4();
    final now = DateTime.now();
    final effectiveBorrowerId = borrowerId.isNotEmpty ? borrowerId : (requesterId ?? '');
    final effectiveBorrowerEmail = borrowerEmail.isNotEmpty ? borrowerEmail : (requesterEmail ?? '');
    final effectiveBorrowerName = borrowerName ?? requesterName;
    final effectiveMessage = message ?? notes;
    final effectiveDays = [1, 3, 7, 14, 30].contains(requestedDays) ? requestedDays : 7;
    final effectiveDue = dueDate ?? now.add(Duration(days: effectiveDays));

    final model = BorrowRequestModel(
      id: requestId,
      documentId: documentId,
      documentTitle: documentTitle,
      borrowerId: effectiveBorrowerId,
      borrowerEmail: effectiveBorrowerEmail,
      borrowerName: effectiveBorrowerName,
      ownerId: ownerId,
      status: 'pending',
      requestedDays: effectiveDays,
      requestedAt: now,
      dueAt: effectiveDue,
      message: effectiveMessage,
    );

    if (client == null) {
      debugPrint('[SupabaseService] Lưu trữ borrow request local/offline');
      return model;
    }

    try {
      // 1. Thử gọi RPC create_borrow_request để đảm bảo xác thực danh tính từ token
      try {
        final res = await client.rpc('create_borrow_request', params: {
          'p_document_id': SupabaseDocumentModel.toValidUuid(documentId),
          'p_requested_days': effectiveDays,
          'p_message': effectiveMessage,
        });
        if (res is Map && res['request_id'] != null) {
          debugPrint('[SupabaseService] => RPC create_borrow_request thành công: ${res['request_id']}');
          return model.copyWith(id: res['request_id'].toString());
        }
      } catch (rpcErr) {
        debugPrint('[SupabaseService] RPC create_borrow_request fallback: $rpcErr');
      }

      // Tra cứu owner_id thật của document từ documents table nếu ownerId truyền vào không phải UUID hoặc trùng borrower_id
      String targetOwnerId = ownerId;
      if (!SupabaseDocumentModel.isValidUuid(targetOwnerId) || targetOwnerId == effectiveBorrowerId) {
        try {
          final docRow = await client
              .from('documents')
              .select('owner_id')
              .eq('id', SupabaseDocumentModel.toValidUuid(documentId))
              .maybeSingle();
          if (docRow != null && docRow['owner_id'] != null) {
            targetOwnerId = docRow['owner_id'] as String;
          }
        } catch (e) {
          debugPrint('[SupabaseService] Tra cứu owner_id của document thất bại: $e');
        }
      }

      if (!SupabaseDocumentModel.isValidUuid(targetOwnerId) && ownerId.contains('@')) {
        try {
          final userRow = await client
              .from('users')
              .select('id')
              .eq('email', ownerId.toLowerCase().trim())
              .maybeSingle();
          if (userRow != null && userRow['id'] != null) {
            targetOwnerId = userRow['id'] as String;
          }
        } catch (_) {}
      }

      String targetBorrowerId = effectiveBorrowerId;
      if (!SupabaseDocumentModel.isValidUuid(targetBorrowerId)) {
        final resolved = await resolveOwnerId();
        if (resolved != null && resolved.isNotEmpty) {
          targetBorrowerId = resolved;
        }
      }

      // 2. Fallback INSERT trực tiếp vào bảng borrow_requests (Khớp 100% cả 2 schema V2 và V6)
      // Đảm bảo due_date và due_at luôn được truyền, không null, và lớn hơn thời điểm bắt đầu mượn
      final payload = {
        'id': requestId,
        'document_id': SupabaseDocumentModel.toValidUuid(documentId),
        'borrower_id': targetBorrowerId,
        'requester_id': targetBorrowerId, // Hỗ trợ schema V2
        'owner_id': targetOwnerId,
        'status': 'pending',
        'requested_days': effectiveDays,
        'due_date': effectiveDue.toIso8601String(), // Bắt buộc cho schema V2 (NOT NULL)
        'due_at': effectiveDue.toIso8601String(),   // Bắt buộc cho schema V6
        'requested_at': now.toIso8601String(),
        'request_date': now.toIso8601String(),      // Hỗ trợ schema V2
        if (effectiveMessage != null && effectiveMessage.isNotEmpty) ...{
          'message': effectiveMessage,
          'notes': effectiveMessage,                // Hỗ trợ schema V2
        },
      };

      await client.from('borrow_requests').insert(payload);
      debugPrint('[SupabaseService] => Đã gửi yêu cầu mượn tài liệu: $requestId (Thời hạn $effectiveDays ngày, Hạn: $effectiveDue)');
      return model;
    } on PostgrestException catch (pgError) {
      final formatted = formatPostgrestError(pgError);
      debugPrint('[SupabaseService] Lỗi Postgrest khi tạo borrow request: $formatted ($pgError)');
      throw StateError(formatted);
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tạo borrow request trên Supabase: $e');
      rethrow;
    }
  }

  /// Phê duyệt yêu cầu mượn tài liệu (Chỉ Owner)
  Future<void> approveBorrowRequest(String requestId) async {
    final client = this.client;
    if (client == null) return;

    try {
      try {
        await client.rpc('approve_borrow_request', params: {'p_request_id': requestId});
        debugPrint('[SupabaseService] => RPC approve_borrow_request thành công: $requestId');
        return;
      } catch (rpcErr) {
        debugPrint('[SupabaseService] RPC approve_borrow_request fallback: $rpcErr');
      }

      final now = DateTime.now();
      // Lấy thông tin requested_days của bản ghi hiện tại để tính đúng hạn mượn bắt đầu từ thời điểm duyệt
      int days = 7;
      try {
        final existing = await client
            .from('borrow_requests')
            .select('requested_days')
            .eq('id', requestId)
            .maybeSingle();
        if (existing != null && existing['requested_days'] != null) {
          days = (existing['requested_days'] as num).toInt();
        }
      } catch (_) {}

      final newDueDate = now.add(Duration(days: days > 0 ? days : 7));

      await client.from('borrow_requests').update({
        'status': 'approved',
        'approved_at': now.toIso8601String(),
        'due_at': newDueDate.toIso8601String(),
        'due_date': newDueDate.toIso8601String(), // Cập nhật cả 2 cột tương thích
        'updated_at': now.toIso8601String(),
      }).eq('id', requestId);
      debugPrint('[SupabaseService] => Đã duyệt yêu cầu mượn $requestId (Hạn mới: $newDueDate)');
    } on PostgrestException catch (pgError) {
      final formatted = formatPostgrestError(pgError);
      debugPrint('[SupabaseService] Lỗi khi duyệt yêu cầu mượn: $formatted');
      throw StateError(formatted);
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi duyệt yêu cầu mượn: $e');
      rethrow;
    }
  }

  /// Từ chối yêu cầu mượn tài liệu (Chỉ Owner)
  Future<void> rejectBorrowRequest(String requestId, {String? reason}) async {
    final client = this.client;
    if (client == null) return;

    try {
      try {
        await client.rpc('reject_borrow_request', params: {
          'p_request_id': requestId,
          'p_reason': reason,
        });
        debugPrint('[SupabaseService] => RPC reject_borrow_request thành công: $requestId');
        return;
      } catch (rpcErr) {
        debugPrint('[SupabaseService] RPC reject_borrow_request fallback: $rpcErr');
      }

      await client.from('borrow_requests').update({
        'status': 'rejected',
        'owner_notes': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      debugPrint('[SupabaseService] => Đã từ chối yêu cầu mượn $requestId');
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi từ chối yêu cầu mượn: $e');
      rethrow;
    }
  }

  /// Hủy yêu cầu mượn tài liệu (Dành cho người mượn khi đang pending)
  Future<void> cancelBorrowRequest(String requestId) async {
    final client = this.client;
    if (client == null) return;

    try {
      try {
        await client.rpc('cancel_borrow_request', params: {'p_request_id': requestId});
        debugPrint('[SupabaseService] => RPC cancel_borrow_request thành công: $requestId');
        return;
      } catch (rpcErr) {
        debugPrint('[SupabaseService] RPC cancel_borrow_request fallback: $rpcErr');
      }

      await client.from('borrow_requests').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      debugPrint('[SupabaseService] => Đã hủy yêu cầu mượn $requestId');
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi hủy yêu cầu mượn: $e');
      rethrow;
    }
  }

  /// Trả tài liệu sớm hoặc Owner nhận lại sách
  Future<void> returnBorrowDocument(String requestId) async {
    final client = this.client;
    if (client == null) return;

    try {
      try {
        await client.rpc('return_borrow_document', params: {'p_request_id': requestId});
        debugPrint('[SupabaseService] => RPC return_borrow_document thành công: $requestId');
        return;
      } catch (rpcErr) {
        debugPrint('[SupabaseService] RPC return_borrow_document fallback: $rpcErr');
      }

      final now = DateTime.now();
      await client.from('borrow_requests').update({
        'status': 'returned',
        'returned_at': now.toIso8601String(),
        'return_date': now.toIso8601String(), // compatibility
        'updated_at': now.toIso8601String(),
      }).eq('id', requestId);
      debugPrint('[SupabaseService] => Đã hoàn trả tài liệu $requestId');
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi trả tài liệu: $e');
      rethrow;
    }
  }

  /// Lấy danh sách yêu cầu mượn người khác gửi đến tôi (Owner)
  Future<List<BorrowRequestModel>> fetchIncomingBorrowRequests(String ownerId) async {
    final client = this.client;
    if (client == null) return [];

    try {
      final rows = await client
          .from('borrow_requests')
          .select('*, documents(title), borrower:users!borrower_id(email, display_name)')
          .eq('owner_id', ownerId)
          .order('requested_at', ascending: false);

      return (rows as List<dynamic>)
          .map((r) => BorrowRequestModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tải incoming borrow requests: $e');
      // Thử fallback query với requester_id cũ nếu có
      try {
        final rowsOld = await client
            .from('borrow_requests')
            .select('*, documents(title), requester:users!requester_id(email, display_name)')
            .eq('owner_id', ownerId)
            .order('request_date', ascending: false);
        return (rowsOld as List<dynamic>)
            .map((r) => BorrowRequestModel.fromJson(r as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Lấy danh sách yêu cầu tôi đã gửi đi mượn tài liệu
  Future<List<BorrowRequestModel>> fetchMyBorrowRequests(String borrowerId) async {
    final client = this.client;
    if (client == null) return [];

    try {
      final rows = await client
          .from('borrow_requests')
          .select('*, documents(title), owner:users!owner_id(email, display_name)')
          .eq('borrower_id', borrowerId)
          .order('requested_at', ascending: false);

      return (rows as List<dynamic>)
          .map((r) => BorrowRequestModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tải my borrow requests: $e');
      // Thử fallback query với requester_id cũ
      try {
        final rowsOld = await client
            .from('borrow_requests')
            .select('*, documents(title), owner:users!owner_id(email, display_name)')
            .eq('requester_id', borrowerId)
            .order('request_date', ascending: false);
        return (rowsOld as List<dynamic>)
            .map((r) => BorrowRequestModel.fromJson(r as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Tải danh sách các tài liệu mà người dùng hiện tại ĐANG ĐƯỢC MƯỢN (approved, còn hạn, chưa trả)
  Future<List<DocumentModel>> fetchBorrowedDocumentsForCurrentUser() async {
    final client = this.client;
    if (client == null) return [];

    try {
      final currentUserId = await resolveOwnerId();
      if (currentUserId == null) return [];

      // Lấy danh sách document_id từ borrow_requests đang approved và chưa hết hạn
      final borrowRows = await client
          .from('borrow_requests')
          .select('document_id, due_at, due_date')
          .eq('borrower_id', currentUserId)
          .eq('status', 'approved')
          .isFilter('returned_at', null);

      if (borrowRows.isEmpty) return [];

      final activeDocIds = <String>[];
      for (final r in borrowRows) {
        final dueStr = r['due_at'] as String? ?? r['due_date'] as String?;
        if (dueStr != null) {
          final due = DateTime.tryParse(dueStr);
          if (due != null && due.isAfter(DateTime.now())) {
            activeDocIds.add(r['document_id'] as String);
          }
        }
      }

      if (activeDocIds.isEmpty) return [];

      // Truy vấn tài liệu qua PostgREST (RLS documents_select sẽ cho phép vì has_active_borrow = true)
      final docRows = await client
          .from('documents')
          .select('*, owner:users!owner_id(email, display_name)')
          .inFilter('id', activeDocIds);

      return (docRows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final ownerMap = map['owner'] as Map<String, dynamic>?;
        return DocumentModel(
          id: map['id'] as String? ?? '',
          title: map['title'] as String? ?? '',
          subject: map['subject'] as String? ?? '',
          categoryId: map['category_id'] as String? ?? 'all',
          filePathOrUrl: map['storage_path'] as String?,
          notes: map['description'] as String?,
          tags: parseTagsList(map['tags_cache'] ?? map['tags']),
          locationName: map['location_name'] as String?,
          building: map['building'] as String?,
          floor: map['floor'] as String?,
          shelf: map['shelf'] as String?,
          physicalLocation: map['physical_location'] as String?,
          latitude: (map['latitude'] as num?)?.toDouble(),
          longitude: (map['longitude'] as num?)?.toDouble(),
          locationNotes: map['location_notes'] as String?,
          isAvailableForBorrow: map['is_borrowable'] as bool? ?? false,
          isDiscoverable: map['is_discoverable'] as bool? ?? false,
          isBorrowable: map['is_borrowable'] as bool? ?? false,
          userPermissionRole: 'viewer', // Quyền mượn chỉ là Viewer
          ownerEmail: ownerMap != null ? ownerMap['email'] as String? : null,
          ownerName: ownerMap != null ? ownerMap['display_name'] as String? : null,
          createdDate: map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now(),
          updatedDate: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) ?? DateTime.now() : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseService] Lỗi khi tải tài liệu đang mượn: $e');
      return [];
    }
  }

  /// Cập nhật trạng thái yêu cầu mượn (tương thích ngược)
  Future<void> updateBorrowRequestStatus({
    required String requestId,
    required String status,
    String? ownerNotes,
  }) async {
    switch (status) {
      case 'approved':
        return approveBorrowRequest(requestId);
      case 'rejected':
        return rejectBorrowRequest(requestId, reason: ownerNotes);
      case 'cancelled':
        return cancelBorrowRequest(requestId);
      case 'returned':
        return returnBorrowDocument(requestId);
      default:
        final client = this.client;
        if (client == null) return;
        await client.from('borrow_requests').update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);
    }
  }
}
