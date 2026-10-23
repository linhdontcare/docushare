import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/document_model.dart';
import '../../domain/models/supabase_document_model.dart';
import '../../firebase_options.dart';
import '../supabase/supabase_service.dart';

typedef UploadProgressCallback = void Function(double progress);

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  /// Giải mã an toàn Payload của token JWT mà không in Signature hay toàn bộ token thô
  static Map<String, dynamic>? decodeTokenPayload(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? _auth;
  FirebaseStorage? _storage;
  bool _initialized = false;
  String? _initializationError;
  Future<void>? _googleSignInInitialization;
  static const String _googleServerClientId =
      '429349029932-56jueiai9q63pf7bs2turfg2hoq6i1kt.apps.googleusercontent.com';

  bool get isAvailable => _initialized;
  String? get initializationError => _initializationError;
  User? get currentUser => _auth?.currentUser;
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream<User?>.empty();

  /// Cờ cấu hình: Mặc định kết nối Firebase Storage Cloud thật.
  /// Chỉ bật Storage Emulator khi truyền cờ --dart-define=USE_FIREBASE_STORAGE_EMULATOR=true
  static const bool _useStorageEmulator = bool.fromEnvironment(
    'USE_FIREBASE_STORAGE_EMULATOR',
    defaultValue: false,
  );

  bool get isStorageEmulatorActive => _useStorageEmulator;
  String get storageBucket => _storage?.bucket ?? '';

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _auth = FirebaseAuth.instance;
      // Firestore không sử dụng trong DocuShare (sử dụng Supabase Database + Drift SQLite)
      // Không khởi tạo FirebaseFirestore.instance để tránh spam lỗi database '(default)' not found
      _storage = FirebaseStorage.instance;
      _storage!.setMaxUploadRetryTime(const Duration(seconds: 45));
      _storage!.setMaxOperationRetryTime(const Duration(seconds: 45));

      // Cấu hình Firebase Storage Emulator cho môi trường Development (Debug Mode)
      // Giữ nguyên Auth và Firestore thật trên Cloud
      if (_useStorageEmulator) {
        final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            ? '10.0.2.2'
            : 'localhost';
        const port = 9199;
        try {
          _storage!.useStorageEmulator(host, port);
          // Giảm thời gian retry mặc định từ 10 phút xuống 15 giây để phát hiện lỗi mạng/emulator ngay lập tức
          _storage!.setMaxUploadRetryTime(const Duration(seconds: 15));
          _storage!.setMaxOperationRetryTime(const Duration(seconds: 15));

          debugPrint('============================================================');
          debugPrint('[FirebaseService] [STORAGE EMULATOR KÍCH HOẠT THÀNH CÔNG]');
          debugPrint('[FirebaseService]   * Host: $host | Port: $port');
          debugPrint('[FirebaseService]   * Nền tảng: ${defaultTargetPlatform.name}');
          debugPrint('[FirebaseService]   * Bucket: ${_storage!.bucket}');
          debugPrint('[FirebaseService]   * Firebase Auth: Google Sign-In Cloud THẬT');
          debugPrint('[FirebaseService]   * Cloud Firestore: Cloud Firestore THẬT');
          debugPrint('[FirebaseService]   * Supabase PostgreSQL: Cloud THẬT');
          debugPrint('============================================================');
        } catch (emulatorErr) {
          debugPrint('[FirebaseService] Lưu ý khi cấu hình Storage Emulator: $emulatorErr');
        }
      }

      _initialized = true;
      _initializationError = null;
    } on Object catch (error) {
      _initializationError = _formatFirebaseError(error);
      throw StateError(_initializationError!);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    _ensureInitialized();
    UserCredential result;

    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      result = await _auth!.signInWithPopup(googleProvider);
    } else {
      _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      try {
        await _googleSignInInitialization;
      } catch (_) {
        _googleSignInInitialization = null;
        rethrow;
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google không trả về ID token hợp lệ.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      result = await _auth!.signInWithCredential(credential);
    }

    final user = result.user;
    if (user == null) {
      throw StateError('Firebase không tạo được phiên đăng nhập.');
    }

    debugPrint('============================================================');
    debugPrint('[Firebase Auth] Đăng nhập Google thành công!');
    debugPrint('[Firebase Auth]   * UID: ${user.uid}');
    debugPrint('[Firebase Auth]   * Email: ${user.email}');
    debugPrint('[Firebase Auth]   * Tên: ${user.displayName}');

    // 1. Tự động kiểm tra và gán Custom Claim { role: 'authenticated' } cho tài khoản
    // Đảm bảo Supabase PostgREST nhận diện hợp lệ mà không bị fallback về anon (lỗi 42501)
    await ensureSupabaseAuthenticatedRole(user);

    // 2. Trích xuất Firebase ID Token và kiểm tra chẩn đoán an toàn
    try {
      final token = await user.getIdToken();
      if (token != null && token.isNotEmpty) {
        final claims = decodeTokenPayload(token);
        if (claims != null) {
          debugPrint('[Firebase Auth JWT Claims]');
          debugPrint('  * Issuer (iss): ${claims['iss']}');
          debugPrint('  * Audience (aud / Project ID): ${claims['aud']}');
          debugPrint('  * Subject (sub / UID): ${claims['sub']}');
          debugPrint('  * Email (email): ${claims['email']}');
          final role = claims['role'];
          debugPrint('  * Claim "role": ${role ?? "(CHƯA CÓ)"}');
          if (role == 'authenticated') {
            debugPrint('  [XÁC THỰC RLS HỢP LỆ]: Token ĐÃ CÓ claim "role": "authenticated". Sẵn sàng!');
          }
        }
      }
    } catch (tokenErr) {
      debugPrint('[Firebase Auth] Lỗi trích xuất ID Token: $tokenErr');
    }

    // 3. Thông tin người dùng được quản lý và đồng bộ tập trung trên Supabase public.users

    // 4. Đồng bộ người dùng Google sang Supabase public.users
    if (SupabaseService.instance.isAvailable) {
      try {
        debugPrint('[Firebase Auth] Bắt đầu đồng bộ người dùng sang Supabase public.users...');
        await SupabaseService.instance.syncUser(
          firebaseUid: user.uid,
          email: (user.email ?? '').trim().toLowerCase(),
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );
        debugPrint('[Firebase Auth] Đồng bộ sang Supabase hoàn tất thành công!');
      } catch (supabaseError) {
        debugPrint('[Firebase Auth] Lưu ý: Đồng bộ Supabase thất bại: $supabaseError');
      }
    } else {
      debugPrint('[Firebase Auth] SupabaseService chưa khả dụng: ${SupabaseService.instance.initializationError}');
    }
    debugPrint('============================================================');

    return result;
  }

  /// Đảm bảo người dùng Firebase có Custom Claim { role: 'authenticated' }
  /// URL mặc định của Cloud Function HTTPS cho Firebase Project docushare-db
  static const String _defaultFunctionsUrl =
      'https://us-central1-docushare-db.cloudfunctions.net/assignUserRole';

  /// Cho phép cấu hình URL linh hoạt qua --dart-define=FIREBASE_FUNCTIONS_URL=...
  static const String _functionsUrl = String.fromEnvironment(
    'FIREBASE_FUNCTIONS_URL',
    defaultValue: _defaultFunctionsUrl,
  );

  /// Kiểm tra và tự động gán Firebase Custom Claim role = 'authenticated'
  /// qua Cloud Function nếu tài khoản chưa có.
  /// 
  /// 1. Kiểm tra claims hiện tại của ID Token (không gọi Function nếu đã có role = authenticated).
  /// 2. Nếu chưa có, lấy ID Token và gửi POST request đến Cloud Function với header Bearer Token.
  /// 3. Cloud Function tự động trích xuất UID từ token đã verify trên server và gán claim.
  /// 4. Làm mới token (forceRefresh = true) và xác nhận claim role = 'authenticated' trước khi trả về.
  Future<bool> assignUserClaimViaFunction(User user) async {
    _ensureInitialized();

    try {
      // 1. Kiểm tra claims hiện tại: Luôn forceRefresh để đảm bảo lấy token mới nhất từ server
      final currentTokenResult = await user.getIdTokenResult(true);
      if (currentTokenResult.claims?['role'] == 'authenticated') {
        debugPrint('[FirebaseService] Tài khoản ${user.email} (${user.uid}) ĐÃ CÓ claim role = authenticated qua getIdTokenResult(true). Bỏ qua gọi Cloud Function.');
        return true;
      }

      debugPrint('[FirebaseService] Tài khoản ${user.email} (${user.uid}) CHƯA CÓ claim role = authenticated.');
      debugPrint('[FirebaseService] Bắt đầu gọi Cloud Function: $_functionsUrl ...');

      // 2. Lấy Firebase ID Token mới nhất của người dùng
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Không thể lấy Firebase ID Token của người dùng.');
      }

      // 3. Gửi HTTP POST request tới Cloud Function
      final response = await http.post(
        Uri.parse(_functionsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Quá thời gian kết nối tới Cloud Function (25s).'),
      );

      debugPrint('[FirebaseService] Cloud Function phản hồi: HTTP ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          debugPrint('[FirebaseService] Cloud Function xác nhận: ${data['message']}');

          // 4. Bắt buộc gọi getIdTokenResult(true) để làm mới token và xác nhận role = authenticated
          final refreshedResult = await user.getIdTokenResult(true);
          final newRole = refreshedResult.claims?['role'];
          if (newRole == 'authenticated') {
            debugPrint('[FirebaseService] => Xác nhận Token đã có claim role = authenticated sau khi làm mới!');
            return true;
          } else {
            throw StateError('Đã gọi Cloud Function thành công nhưng Token sau khi reload vẫn chưa nhận role = authenticated (hiện tại: $newRole).');
          }
        } else {
          final errMsg = data['error'] as String? ?? 'Cloud Function trả về success = false';
          throw StateError(errMsg);
        }
      } else {
        throw StateError('Lỗi Cloud Function [${response.statusCode}]: ${response.body}');
      }
    } catch (e) {
      debugPrint('[FirebaseService] Lỗi khi gọi Cloud Function assignUserRole: $e');
      rethrow;
    }
  }

  /// Tương thích ngược: đảm bảo có role authenticated
  Future<bool> ensureSupabaseAuthenticatedRole(User user) async {
    return assignUserClaimViaFunction(user);
  }

  Future<void> signOut() async {
    _ensureInitialized();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth!.signOut();
  }

  Future<String> uploadDocument({
    required String documentId,
    File? file,
    Uint8List? fileBytes,
    required String fileName,
    required String contentType,
    UploadProgressCallback? onProgress,
  }) async {
    _ensureInitialized();
    final user = _auth!.currentUser;
    if (user == null) {
      throw StateError('Cần đăng nhập Google trước khi tải tệp lên Cloud.');
    }

    final docUuid = SupabaseDocumentModel.toValidUuid(documentId);
    String safeExt = p.extension(fileName).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (safeExt.isEmpty) safeExt = 'bin';
    final safeFileName = '$docUuid.$safeExt';
    final storagePath = 'users/${user.uid}/documents/$docUuid/$safeFileName';

    final fileSize = fileBytes?.length ?? (file != null ? await file.length() : 0);
    if (fileSize > 20 * 1024 * 1024) {
      throw StateError('Tệp vượt quá giới hạn 20 MB ($fileSize bytes).');
    }

    // ========================================================================
    // ƯU TIÊN 1: SUPABASE STORAGE (HOÀN TOÀN MIỄN PHÍ - KHÔNG CẦN GÓI BLAZE)
    // ========================================================================
    if (SupabaseService.instance.isAvailable) {
      try {
        debugPrint('------------------------------------------------------------');
        debugPrint('[Storage] Đang tải tệp lên Supabase Storage (Miễn phí 1GB, không cần Blaze)...');
        debugPrint('  * Path: $storagePath');
        debugPrint('  * File hiển thị: $fileName | Tên lưu trữ an toàn: $safeFileName ($fileSize bytes)');
        debugPrint('  * Content-Type: $contentType');
        await SupabaseService.instance.uploadDocumentFile(
          path: storagePath,
          file: file,
          fileBytes: fileBytes,
          contentType: contentType,
        );
        onProgress?.call(1);
        debugPrint('[Storage] => TẢI LÊN SUPABASE STORAGE HOÀN TẤT THÀNH CÔNG!');
        debugPrint('------------------------------------------------------------');
        return storagePath;
      } catch (supabaseErr) {
        debugPrint('[Storage] Tải lên Supabase Storage thất bại: $supabaseErr');
        final errStr = supabaseErr.toString();
        if (errStr.contains('Bucket not found') ||
            errStr.contains('not found') ||
            errStr.contains('404')) {
          throw StateError(
            'Chưa tạo bucket "documents" trên Supabase. '
            'Vui lòng vào Supabase Dashboard -> Storage -> New bucket -> Đặt tên "documents" và bật "Public bucket"!',
          );
        }
        throw StateError('Lỗi tải tệp lên Supabase Storage: $supabaseErr');
      }
    }

    // ========================================================================
    // ƯU TIÊN 2: FIREBASE STORAGE (NẾU DỰ ÁN ĐÃ KÍCH HOẠT)
    // ========================================================================
    final reference = _storage!.ref(storagePath);
    debugPrint('------------------------------------------------------------');
    debugPrint('[Firebase Storage] [BẮT ĐẦU UPLOAD TỆP]');
    debugPrint('[Firebase Storage]   * Path: $storagePath');
    debugPrint('[Firebase Storage]   * File: $fileName ($fileSize bytes)');
    debugPrint('[Firebase Storage]   * Content-Type: $contentType');
    debugPrint('[Firebase Storage]   * Bucket đích: ${_storage!.bucket}');
    debugPrint('[Firebase Storage]   * Emulator đang bật: $_useStorageEmulator');
    debugPrint('------------------------------------------------------------');

    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {'ownerId': user.uid},
    );

    final UploadTask uploadTask;
    if (fileBytes != null) {
      uploadTask = reference.putData(fileBytes, metadata);
    } else if (file != null) {
      uploadTask = reference.putFile(file, metadata);
    } else {
      throw ArgumentError('Cần cung cấp file hoặc fileBytes để tải lên Storage.');
    }

    final subscription = uploadTask.snapshotEvents.listen(
      (snapshot) {
        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;
        final state = snapshot.state;
        debugPrint('[Firebase Storage Tiến độ] Trạng thái: $state | Đã gửi: $transferred / $total bytes');
        if (total > 0) {
          onProgress?.call(transferred / total);
        }
      },
      onError: (err) {
        debugPrint('[Firebase Storage Tiến độ LỖI]: $err');
      },
    );

    try {
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint('[Firebase Storage] !!! TIMEOUT: UploadTask quá thời gian chờ (45s). Hủy tác vụ.');
          uploadTask.cancel();
          throw TimeoutException(
            'Quá thời gian tải tệp lên Storage (Timeout 45s). Vui lòng thử lại.',
          );
        },
      );
      debugPrint('[Firebase Storage] => UPLOAD HOÀN TẤT THÀNH CÔNG! State: ${snapshot.state}, Bytes: ${snapshot.totalBytes}');
      onProgress?.call(1);
    } on FirebaseException catch (fbErr) {
      debugPrint('[Firebase Storage] !!! LỖI FIREBASE STORAGE: Mã=${fbErr.code}, Thông điệp=${fbErr.message}');
      rethrow;
    } catch (e) {
      debugPrint('[Firebase Storage] !!! LỖI KHÔNG XÁC ĐỊNH KHI UPLOAD: $e');
      rethrow;
    } finally {
      await subscription.cancel();
    }

    return storagePath;
  }

  Stream<List<DocumentModel>> watchUserDocuments() {
    // Trả về stream rỗng, DocuShare quản lý tài liệu qua Supabase và Drift SQLite
    return const Stream<List<DocumentModel>>.empty();
  }

  /// Tải lại toàn bộ tài liệu của người dùng hiện tại (No-op, dữ liệu do Supabase đảm nhiệm)
  Future<List<DocumentModel>> getUserDocuments() async {
    return const [];
  }

  Future<String> getDownloadUrl(String storagePath) async {
    _ensureInitialized();
    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      return storagePath;
    }
    // 1. Lấy Public URL từ Supabase Storage nếu có
    if (SupabaseService.instance.isAvailable) {
      final supabaseUrl = SupabaseService.instance.getPublicUrl(storagePath);
      if (supabaseUrl.isNotEmpty) return supabaseUrl;
    }
    // 2. Thử Firebase Storage
    return await _storage!.ref(storagePath).getDownloadURL();
  }

  Future<File> downloadDocumentToTemporaryFile({
    required String storagePath,
    required String fileName,
    required String documentId,
  }) async {
    _ensureInitialized();
    final user = _auth!.currentUser;
    if (user == null) {
      throw StateError('Cần đăng nhập Google để mở tài liệu Cloud.');
    }
    if (!storagePath.startsWith('users/')) {
      throw StateError('Đường dẫn tài liệu không hợp lệ: $storagePath');
    }

    final directory = await Directory(
      p.join(Directory.systemTemp.path, 'DocuShare', 'CloudDocuments'),
    ).create(recursive: true);
    final safeName = p.basename(fileName);
    final file = File(p.join(directory.path, '${documentId}_$safeName'));

    // Thử tải từ Supabase Storage trước
    if (SupabaseService.instance.isAvailable) {
      try {
        final downloaded = await SupabaseService.instance.downloadToTemporaryFile(
          storagePath: storagePath,
          fileName: '${documentId}_$safeName',
        );
        if (downloaded is File) return downloaded;
      } catch (e) {
        debugPrint('[Download] Supabase Storage fallback: $e, thử Firebase...');
      }
    }

    // Fallback sang Firebase Storage
    await _storage!.ref(storagePath).writeToFile(file);
    return file;
  }

  /// Xóa tệp vật lý trên Supabase Storage (và Firebase Storage Emulator nếu được bật)
  Future<void> deleteStorageFile({required String storagePath}) async {
    _ensureInitialized();
    final user = _auth!.currentUser;
    if (user == null) {
      throw StateError('Cần đăng nhập Google để thực hiện xóa tệp Cloud.');
    }

    // Nếu đường dẫn không thuộc thư mục users, ghi log và bỏ qua thay vì làm dừng luồng xóa
    if (!storagePath.startsWith('users/')) {
      debugPrint('[DELETE] Bỏ qua xóa Storage vì đường dẫn không phải tệp người dùng: $storagePath');
      return;
    }

    debugPrint('[DELETE] Storage path: $storagePath');

    // 1. Xóa trên Supabase Storage (Nơi lưu trữ chính thức của DocuShare)
    if (SupabaseService.instance.isAvailable) {
      try {
        await SupabaseService.instance.deleteStorageFile(storagePath);
        debugPrint('[DELETE] Supabase Storage: Đã yêu cầu xóa tệp $storagePath');
      } catch (supabaseErr) {
        debugPrint('[DELETE] Supabase Storage warning: $supabaseErr');
      }
    }

    // 2. Chỉ xóa trên Firebase Storage nếu Emulator đang hoạt động (tránh treo trên Cloud Storage thật)
    if (_useStorageEmulator && _storage != null) {
      try {
        await _storage!.ref(storagePath).delete().timeout(const Duration(seconds: 3));
        debugPrint('[DELETE] Firebase Storage Emulator: Đã xóa tệp $storagePath');
      } catch (_) {}
    }
  }

  /// Xóa bản ghi tài liệu trên Cloud Firestore (No-op do sử dụng Supabase public.documents)
  Future<void> deleteFirestoreDocument({required String documentId}) async {
    return;
  }

  Future<void> deleteDocument({
    required String documentId,
    String? storagePath,
  }) async {
    _ensureInitialized();
    final user = _auth!.currentUser;
    if (user == null) return;

    if (storagePath != null && storagePath.isNotEmpty) {
      await deleteStorageFile(storagePath: storagePath);
    }
    await deleteFirestoreDocument(documentId: documentId);
  }

  /// Chỉ xóa tệp vật lý trên Firebase Storage, không xóa bản ghi Firestore (dùng khi thay tệp mới)
  Future<void> deleteStorageFileOnly({required String storagePath}) async {
    await deleteStorageFile(storagePath: storagePath);
  }

  /// Lưu metadata lên Firestore (No-op do metadata lưu trữ chính thức trên Supabase public.documents)
  Future<void> saveDocumentMetadata({
    required String documentId,
    required Map<String, Object?> data,
  }) async {
    return;
  }

  void _ensureInitialized() {
    if (!_initialized ||
        _auth == null ||
        _storage == null) {
      throw StateError(
        'Firebase chưa sẵn sàng. Hãy kiểm tra Firebase project và chạy '
        'flutterfire configure.',
      );
    }
  }

  String _formatFirebaseError(Object error) {
    if (error is FirebaseException) {
      return '${error.code}: ${error.message ?? 'Firebase initialization failed.'}';
    }
    if (error is UnsupportedError) {
      return error.message?.toString() ??
          'Nền tảng hiện tại chưa được cấu hình Firebase.';
    }
    return error.toString();
  }

}
