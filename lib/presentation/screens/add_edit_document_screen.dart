// ==============================================================================
// PRESENTATION LAYER: Add / Edit Document Screen (Deep Tech Emerald)
// Màn hình biểu mẫu thêm mới hoặc chỉnh sửa thông tin tài liệu học tập.
// Tuân thủ Flutter Box Model: SafeArea, SingleChildScrollView, Padding, Column.
// Đồng bộ phong cách nhận diện Deep Tech Emerald:
// - Scaffold: Deep Slate Navy (#0F172A)
// - Container/Inputs: Dark Slate (#1E293B)
// - Primary Accent: Emerald Green (#10B981)
// ==============================================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/firebase/firebase_service.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/converters/type_converters.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/supabase_document_model.dart';
import '../providers/document_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/location_picker_widget.dart';
import '../widgets/tag_selector_widget.dart';

/// Sao chép tệp được chọn vào vùng lưu trữ riêng của ứng dụng.
Future<String> copyFileToApplicationDocumentsDirectory(
  String sourcePath,
) async {
  if (kIsWeb) return sourcePath;
  final appDirectory = await getApplicationDocumentsDirectory();
  final documentsDirectory = Directory(
    p.join(appDirectory.path, 'EduVault', 'Documents'),
  );
  await documentsDirectory.create(recursive: true);

  final fileName = p.basename(sourcePath);
  final targetPath = p.join(documentsDirectory.path, fileName);

  // Nếu tệp đã nằm trong thư mục riêng thì không tự sao chép đè lên chính nó.
  if (p.normalize(sourcePath) == p.normalize(targetPath)) {
    return targetPath;
  }

  var uniqueTargetPath = targetPath;
  if (await File(uniqueTargetPath).exists()) {
    final extension = p.extension(fileName);
    final baseName = p.basenameWithoutExtension(fileName);
    uniqueTargetPath = p.join(
      documentsDirectory.path,
      '${baseName}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
  }

  await File(sourcePath).copy(uniqueTargetPath);
  return uniqueTargetPath;
}

class AddEditDocumentScreen extends StatefulWidget {
  final DocumentModel? document;

  const AddEditDocumentScreen({super.key, this.document});

  @override
  State<AddEditDocumentScreen> createState() => _AddEditDocumentScreenState();
}

class _AddEditDocumentScreenState extends State<AddEditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final TextEditingController _webUrlController;
  late final TextEditingController _notesController;

  String? _selectedCategoryId;
  DocumentPriority _selectedPriority = DocumentPriority.low;
  bool _isSaving = false;
  bool _isPickingFile = false;
  bool _isOpeningFile = false;
  double? _uploadProgress;

  // Dữ liệu tệp hiện có trên Cloud (Storage)
  String? _existingStoragePath;
  String? _existingFileName;
  String? _existingFileExtension;
  int? _existingFileSize;
  String? _existingFileType;

  // Dữ liệu tệp mới được người dùng chọn từ thiết bị (để thay thế hoặc thêm mới)
  String? _newSelectedFilePath;
  Uint8List? _newSelectedFileBytes;
  String? _newSelectedFileName;
  String? _newSelectedFileExtension;
  int? _newSelectedFileSize;

  // Quản lý Thẻ phân loại (Tags) & Vị trí vật lý (Physical Location)
  List<String> _tags = [];
  String? _locationName;
  String? _building;
  String? _floor;
  String? _shelf;
  String? _physicalLocation;
  double? _latitude;
  double? _longitude;
  String? _locationNotes;
  bool _isDiscoverable = false;
  bool _isBorrowable = false;

  bool get _isEditMode => widget.document != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _titleController = TextEditingController(text: doc?.title ?? '');
    _subjectController = TextEditingController(text: doc?.subject ?? '');
    _notesController = TextEditingController(text: doc?.notes ?? '');
    _selectedCategoryId = doc?.categoryId ?? CategoryModel.defaultCategories.first.id;
    _selectedPriority = doc?.priority ?? DocumentPriority.low;

    _tags = List<String>.from(doc?.tags ?? []);
    _locationName = doc?.locationName;
    _building = doc?.building;
    _floor = doc?.floor;
    _shelf = doc?.shelf;
    _physicalLocation = doc?.physicalLocation;
    _latitude = doc?.latitude;
    _longitude = doc?.longitude;
    _locationNotes = doc?.locationNotes;
    _isDiscoverable = doc?.isDiscoverable ?? false;
    _isBorrowable = doc?.isBorrowable ?? (doc?.isAvailableForBorrow ?? false);

    final rawPath = doc?.filePathOrUrl?.trim();
    if (doc != null && doc.isWebLink) {
      _webUrlController = TextEditingController(text: rawPath ?? '');
    } else {
      _webUrlController = TextEditingController(text: '');
      if (rawPath != null && rawPath.isNotEmpty) {
        if (rawPath.startsWith('users/')) {
          _existingStoragePath = rawPath;
          _existingFileName = p.basename(rawPath);
          _existingFileExtension = _extensionOf(_existingFileName!);
          _existingFileType = _existingFileExtension;
        } else if (!kIsWeb && File(rawPath).existsSync()) {
          _newSelectedFilePath = rawPath;
          _newSelectedFileName = p.basename(rawPath);
          _newSelectedFileExtension = _extensionOf(_newSelectedFileName!);
          _newSelectedFileSize = File(rawPath).lengthSync();
        }
      }
    }

    _loadExistingFileMetadata();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedCategoryId == null && widget.document == null) {
      final categories = context.read<DocumentProvider>().categories;
      if (categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
    }
  }

  /// Đọc lại metadata của tệp từ Supabase khi mở màn hình chỉnh sửa.
  Future<void> _loadExistingFileMetadata() async {
    final doc = widget.document;
    if (doc == null) return;

    // Nếu tài liệu đã có storage_path trên Cloud
    if (_existingStoragePath != null && _existingStoragePath!.isNotEmpty) {
      final docUuid = SupabaseDocumentModel.toValidUuid(doc.id);
      try {
        final meta = await SupabaseService.instance.getDocumentMetadata(docUuid);
        if (meta != null && mounted) {
          setState(() {
            _isDiscoverable = meta.isDiscoverable;
            _isBorrowable = meta.isBorrowable;
            if (meta.fileName.isNotEmpty) {
              _existingFileName = meta.fileName;
              _existingFileExtension = _extensionOf(meta.fileName);
            }
            if (meta.fileType.isNotEmpty) {
              _existingFileType = meta.fileType.toUpperCase();
            }
            if (meta.fileSize > 0) {
              _existingFileSize = meta.fileSize;
            }
          });
        }
      } catch (e) {
        debugPrint('[AddEditScreen] Lỗi khi nạp metadata tệp từ Supabase: $e');
      }
      return;
    }

    // Nếu là tệp local
    if (!kIsWeb && _newSelectedFilePath != null && _newSelectedFilePath!.isNotEmpty && !_newSelectedFilePath!.startsWith('web_upload://')) {
      final file = File(_newSelectedFilePath!);
      if (await file.exists()) {
        final stat = await file.stat();
        if (mounted) {
          setState(() {
            _newSelectedFileSize = stat.size;
          });
        }
      }
    }
  }

  String _extensionOf(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    return extension.isEmpty ? 'FILE' : extension.toUpperCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _documentTypeLabel(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'Hình ảnh';
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'txt':
        return 'Văn bản';
      default:
        return extension.toUpperCase();
    }
  }

  /// Kiểm tra tính hợp lệ của tệp đính kèm hoặc liên kết web trước khi lưu
  String? _validateAttachment() {
    try {
      final webLink = _webUrlController.text.trim();
      final hasExistingCloudFile =
          _existingStoragePath != null && _existingStoragePath!.isNotEmpty;
      final hasNewSelectedFile =
          _newSelectedFilePath != null && _newSelectedFilePath!.isNotEmpty;

      if (hasExistingCloudFile || hasNewSelectedFile) {
        if (!kIsWeb && hasNewSelectedFile && !_newSelectedFilePath!.startsWith('web_upload://')) {
          try {
            if (!File(_newSelectedFilePath!).existsSync()) {
              return 'Tệp được chọn không còn tồn tại trên thiết bị.';
            }
          } catch (_) {}
        }
        return null;
      }

      if (webLink.isNotEmpty) {
        final uri = Uri.tryParse(webLink);
        final isHttpLink =
            uri != null &&
            (uri.scheme.toLowerCase() == 'http' ||
                uri.scheme.toLowerCase() == 'https');
        if (!isHttpLink || uri.host.isEmpty) {
          return 'Liên kết web không hợp lệ (cần bắt đầu bằng http:// hoặc https://)';
        }
        return null;
      }

      // Tài liệu chỉ có ghi chú hoặc thông tin học tập (Note document) là hợp lệ
      return null;
    } catch (e) {
      debugPrint('[AddEditScreen] Lỗi kiểm tra đính kèm: $e');
      return null;
    }
  }

  /// Xem hoặc mở tệp (tải tạm từ Cloud Storage hoặc mở tệp local)
  Future<void> _handleOpenFile() async {
    if (_isOpeningFile) return;

    // 1. Mở tệp mới chọn từ thiết bị
    if (_newSelectedFilePath != null && _newSelectedFilePath!.isNotEmpty) {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tệp "${_newSelectedFileName ?? "mới chọn"}" đã sẵn sàng trên trình duyệt và sẽ được tải lên khi nhấn Lưu.'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
        return;
      }
      final localFile = File(_newSelectedFilePath!);
      if (await localFile.exists()) {
        final result = await OpenFilex.open(localFile.path);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể mở tệp: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // 2. Tải và mở tệp từ Firebase Storage
    if (_existingStoragePath != null && _existingStoragePath!.isNotEmpty) {
      final doc = widget.document;
      if (doc == null) return;

      setState(() => _isOpeningFile = true);
      try {
        if (kIsWeb) {
          final downloadUrl = await FirebaseService.instance.getDownloadUrl(_existingStoragePath!);
          final uri = Uri.parse(downloadUrl);
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          return;
        }

        final cloudFile = await FirebaseService.instance
            .downloadDocumentToTemporaryFile(
              storagePath: _existingStoragePath!,
              fileName: _existingFileName ?? p.basename(_existingStoragePath!),
              documentId: doc.id,
            );
        final result = await OpenFilex.open(cloudFile.path);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể mở tệp Cloud: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể tải tệp từ Storage: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isOpeningFile = false);
      }
    }
  }

  /// Chọn tệp mới từ thiết bị để thêm mới hoặc thay thế tệp cũ
  Future<void> _pickDocumentFile() async {
    if (_isPickingFile) return;

    setState(() => _isPickingFile = true);
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
        ],
      );

      if (pickedFiles.isEmpty) return;

      final pickedFile = pickedFiles.first;
      final fileName = pickedFile.name;
      final fileSize = await pickedFile.length();

      if (fileSize != null && fileSize > 20 * 1024 * 1024) {
        throw StateError('Tệp vượt quá giới hạn 20 MB.');
      }

      String? targetPath;
      final targetBytes = await pickedFile.readAsBytes();

      if (kIsWeb) {
        targetPath = 'web_upload://$fileName';
      } else {
        final sourcePath = pickedFile.path;
        if (sourcePath == null || sourcePath.trim().isEmpty) {
          throw StateError('Không lấy được đường dẫn của tệp đã chọn.');
        }
        targetPath = await copyFileToApplicationDocumentsDirectory(sourcePath);
      }

      if (!mounted) return;
      setState(() {
        _newSelectedFilePath = targetPath;
        _newSelectedFileBytes = targetBytes;
        _newSelectedFileName = fileName;
        _newSelectedFileExtension = _extensionOf(fileName);
        _newSelectedFileSize = fileSize;
      });

      // Tự động điền tiêu đề nếu chưa nhập
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = p
            .basenameWithoutExtension(fileName)
            .replaceAll(RegExp(r'[_-]+'), ' ')
            .trim();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn tệp: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  /// Hủy chọn tệp mới và quay lại tệp cũ đã lưu trên Cloud (nếu có)
  void _revertNewSelectedFile() {
    setState(() {
      _newSelectedFilePath = null;
      _newSelectedFileBytes = null;
      _newSelectedFileName = null;
      _newSelectedFileExtension = null;
      _newSelectedFileSize = null;
    });
  }

  /// Widget hiển thị thẻ Tệp đính kèm (hỗ trợ tệp Cloud đã upload, tệp mới chọn, hoặc nút chọn)
  Widget _buildFilePickerCard() {
    final hasNewFile = _newSelectedFilePath != null;
    final hasExistingCloudFile =
        _existingStoragePath != null && _existingStoragePath!.isNotEmpty;

    // TRƯỜNG HỢP A: Người dùng vừa chọn tệp mới từ thiết bị
    if (hasNewFile) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor, width: 1.2),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'TỆP MỚI CHỌN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _revertNewSelectedFile,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                  label: Text(
                    hasExistingCloudFile ? 'Giữ tệp cũ' : 'Bỏ chọn',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _newSelectedFileName ?? 'Tệp mới',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildFileInfoChip(
                            _newSelectedFileExtension ?? 'FILE',
                            Icons.description_outlined,
                          ),
                          if (_newSelectedFileSize != null)
                            _buildFileInfoChip(
                              _formatFileSize(_newSelectedFileSize!),
                              Icons.data_usage_rounded,
                            ),
                          _buildFileInfoChip(
                            _documentTypeLabel(_newSelectedFileExtension ?? 'FILE'),
                            Icons.category_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _handleOpenFile,
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Xem trước tệp', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _isPickingFile ? null : _pickDocumentFile,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Đổi tệp khác', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // TRƯỜNG HỢP B: Tài liệu đã có tệp tải lên Firebase Storage (khi mở chỉnh sửa)
    if (hasExistingCloudFile) {
      final fileName = _existingFileName ?? p.basename(_existingStoragePath!);
      final fileExt = _existingFileExtension ?? _extensionOf(fileName);
      final fileTypeLabel = _documentTypeLabel(_existingFileType ?? fileExt);

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Trạng thái "Đã tải lên"
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 13, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text(
                        'ĐÃ TẢI LÊN',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Firebase Storage Emulator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Tên tệp và thông số kích thước, định dạng
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildFileInfoChip(fileExt, Icons.description_outlined),
                          if (_existingFileSize != null && _existingFileSize! > 0)
                            _buildFileInfoChip(
                              _formatFileSize(_existingFileSize!),
                              Icons.data_usage_rounded,
                            ),
                          _buildFileInfoChip(fileTypeLabel, Icons.category_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Các nút thao tác: Xem tệp & Thay tệp mới
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _isOpeningFile ? null : _handleOpenFile,
                    icon: _isOpeningFile
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          )
                        : const Icon(Icons.visibility_rounded, size: 16),
                    label: Text(
                      _isOpeningFile ? 'Đang mở tệp...' : 'Xem / Mở tệp',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (widget.document?.isEditor != true) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.borderSubtle),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _isPickingFile ? null : _pickDocumentFile,
                      icon: const Icon(Icons.file_upload_outlined, size: 16),
                      label: const Text('Thay tệp khác', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    // TRƯỜNG HỢP C: Chưa có tệp nào -> Hiển thị vùng chọn tệp ban đầu
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppTheme.primaryColor.withValues(alpha: 0.8),
      ),
      child: Material(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _isPickingFile ? null : _pickDocumentFile,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isPickingFile
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : const Icon(
                          Icons.upload_file_rounded,
                          color: AppTheme.primaryColor,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn tệp từ máy',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PDF, Word, PowerPoint, hình ảnh...',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _webUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Xử lý Lưu / Cập nhật tài liệu:
  /// Tách bạch tuyệt đối các trường hợp:
  /// 1. Chỉ sửa metadata: Giữ nguyên storage_path, file_name, file_size; không upload lại, không xóa file cũ.
  /// 2. Chọn file mới thay thế: Upload file mới trước, update metadata trỏ đến file mới, chỉ xóa file cũ sau khi toàn bộ thành công.
  /// 3. Thêm mới tài liệu: Upload và lưu Supabase & Firestore & Drift.
  /// Lưu tài liệu:
  /// - Ghi log đầy đủ 7 bước [SAVE-1] đến [SAVE-7] không in token/key nhạy cảm
  /// - Thiết lập timeout mạng cho tất cả thao tác bất đồng bộ
  /// - Rollback tệp Storage an toàn nếu lưu metadata thất bại
  /// - Khối try/catch/finally đảm bảo tắt _isSaving trong mọi trường hợp
  Future<void> _handleSave() async {
    // 0. Ngăn việc nhấn nút Lưu liên tục tạo ra dữ liệu trùng lặp
    if (_isSaving) return;

    // 1. Kiểm tra validation các trường bắt buộc
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng kiểm tra và điền đầy đủ các thông tin bắt buộc (*)'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // 2. Kiểm tra danh mục tài liệu (tự động fallback nếu chưa chọn)
    _selectedCategoryId ??= CategoryModel.defaultCategories.first.id;

    // 3. Kiểm tra đính kèm an toàn
    final attachmentError = _validateAttachment();
    if (attachmentError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attachmentError),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<DocumentProvider>();
    final userProvider = context.read<UserProvider>();
    String? newlyUploadedStoragePath;

    try {
      final now = DateTime.now();
      final webUrl = _webUrlController.text.trim();
      final user = FirebaseService.instance.currentUser;
      DocumentModel? savedDocResult;

      // [SAVE-1] Bắt đầu lưu
      debugPrint('============================================================');
      debugPrint(
        '[SAVE-1] Bắt đầu lưu tài liệu: "${_titleController.text.trim()}" '
        '(Chế độ: ${_isEditMode ? "Chỉnh sửa" : "Thêm mới"})',
      );

      // [SAVE-2] Đã lấy token & xác thực Supabase
      if (user != null) {
        try {
          final idToken = await user.getIdToken().timeout(const Duration(seconds: 10));
          debugPrint('[SAVE-2] Đã lấy token (Độ dài: ${idToken?.length ?? 0})');
        } catch (tokenErr) {
          debugPrint('[SAVE-2] Lỗi lấy token: $tokenErr');
        }
      } else {
        debugPrint('[SAVE-2] Bỏ qua lấy token (Chế độ offline/khách)');
      }

      String? ownerId = userProvider.profile?.id;
      if (user != null) {
        if (ownerId == null || ownerId.trim().isEmpty) {
          try {
            ownerId = await SupabaseService.instance
                .resolveOwnerId()
                .timeout(const Duration(seconds: 15));
          } catch (ownerErr) {
            debugPrint('[SAVE-2] Lỗi resolveOwnerId: $ownerErr');
            throw StateError('Không thể tra cứu hồ sơ người dùng trên Supabase: $ownerErr');
          }
        }
        if (ownerId == null || ownerId.trim().isEmpty) {
          throw StateError(
            'Chưa tìm thấy hồ sơ người dùng trên Supabase Database (bảng public.users). '
            'Vui lòng tải lại trang (F5) hoặc đăng nhập lại để hệ thống tự động đồng bộ.',
          );
        }
      }
      debugPrint('[SAVE-2] Đã xác thực Supabase: ownerId=${ownerId ?? "(chế độ offline)"}');

      if (_isEditMode) {
        final originalDoc = widget.document!;
        final docUuid = SupabaseDocumentModel.toValidUuid(originalDoc.id);

        // ====================================================================
        // TRƯỜNG HỢP ĐẶC BIỆT: NGƯỜI DÙNG LÀ EDITOR (CHỈ SỬA 4 TRƯỜNG METADATA)
        // ====================================================================
        if (originalDoc.isEditor) {
          debugPrint('[SAVE-5] Bắt đầu lưu metadata (Quyền Editor)');
          final updatedDoc = originalDoc.copyWith(
            title: _titleController.text.trim(),
            subject: _subjectController.text.trim(),
            categoryId: _selectedCategoryId!,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tags: _tags,
            locationName: _locationName,
            building: _building,
            floor: _floor,
            shelf: _shelf,
            physicalLocation: _physicalLocation,
            latitude: _latitude,
            longitude: _longitude,
            locationNotes: _locationNotes,
            isAvailableForBorrow: widget.document?.isBorrowable ?? false,
            isDiscoverable: widget.document?.isDiscoverable ?? false,
            isBorrowable: widget.document?.isBorrowable ?? false,
            updatedDate: now,
          );
          await provider.updateDocument(updatedDoc);
          debugPrint('[SAVE-6] Lưu metadata thành công (Editor)');
          debugPrint('[SAVE-7] Hoàn tất');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật metadata tài liệu thành công (Quyền Editor)'),
                backgroundColor: AppTheme.primaryColor,
              ),
            );
            Navigator.of(context).pop(updatedDoc);
          }
          return;
        }

        // ====================================================================
        // TRƯỜNG HỢP 1: NGƯỜI DÙNG CHỦ ĐỘNG CHỌN TỆP MỚI ĐỂ THAY THẾ
        // ====================================================================
        if (_newSelectedFilePath != null) {
          final newFile = (!kIsWeb && !_newSelectedFilePath!.startsWith('web_upload://'))
              ? File(_newSelectedFilePath!)
              : null;
          final newFileName = _newSelectedFileName ?? p.basename(_newSelectedFilePath!);
          final newExtension = p.extension(newFileName).toLowerCase();
          final newFileType = newExtension.replaceFirst('.', '').trim();
          final newFileSize = _newSelectedFileSize ??
              (_newSelectedFileBytes?.length ?? (newFile != null ? await newFile.length() : 0));
          final newContentType = _contentTypeForExtension(newExtension);

          // [SAVE-3] Bắt đầu upload
          debugPrint('[SAVE-3] Bắt đầu upload: $newFileName ($newFileSize bytes)');
          final newStoragePath = await FirebaseService.instance.uploadDocument(
            documentId: originalDoc.id,
            file: newFile,
            fileBytes: _newSelectedFileBytes,
            fileName: newFileName,
            contentType: newContentType,
            onProgress: (progress) {
              if (mounted) setState(() => _uploadProgress = progress);
            },
          );
          newlyUploadedStoragePath = newStoragePath;

          // [SAVE-4] Upload thành công
          debugPrint('[SAVE-4] Upload thành công: $newStoragePath');
          if (mounted) setState(() => _uploadProgress = null);

          // [SAVE-5] Bắt đầu lưu metadata
          debugPrint('[SAVE-5] Bắt đầu lưu metadata');
          if (user != null) {
            final supabaseDoc = SupabaseDocumentModel(
              id: docUuid,
              ownerId: ownerId!,
              title: _titleController.text.trim(),
              description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              subject: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
              categoryId: _selectedCategoryId!,
              fileName: newFileName,
              fileType: newFileType.isEmpty ? 'bin' : newFileType,
              fileSize: newFileSize,
              storagePath: newStoragePath,
              locationName: _locationName,
              building: _building,
              floor: _floor,
              shelf: _shelf,
              physicalLocation: _physicalLocation,
              latitude: _latitude,
              longitude: _longitude,
              locationNotes: _locationNotes,
              isAvailableForBorrow: _isBorrowable,
              isDiscoverable: _isDiscoverable,
              isBorrowable: _isBorrowable,
              createdAt: originalDoc.createdDate,
              updatedAt: now,
            );
            await SupabaseService.instance.updateDocumentMetadata(
              id: docUuid,
              data: supabaseDoc.toJsonForFileUpdate(),
            );
          }


          final updatedDoc = originalDoc.copyWith(
            title: _titleController.text.trim(),
            subject: _subjectController.text.trim(),
            categoryId: _selectedCategoryId!,
            filePathOrUrl: newStoragePath,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tags: _tags,
            priority: _selectedPriority,
            locationName: _locationName,
            building: _building,
            floor: _floor,
            shelf: _shelf,
            physicalLocation: _physicalLocation,
            latitude: _latitude,
            longitude: _longitude,
            locationNotes: _locationNotes,
            isAvailableForBorrow: _isBorrowable,
            isDiscoverable: _isDiscoverable,
            isBorrowable: _isBorrowable,
            updatedDate: now,
          );
          await provider.updateDocument(updatedDoc);
          savedDocResult = updatedDoc;

          // [SAVE-6] Lưu metadata thành công
          debugPrint('[SAVE-6] Lưu metadata thành công');

          // Xóa tệp cũ an toàn chỉ sau khi mọi bước lưu thành công
          if (_existingStoragePath != null &&
              _existingStoragePath!.isNotEmpty &&
              _existingStoragePath != newStoragePath) {
            try {
              debugPrint('[AddEditScreen] Xóa tệp cũ đã được thay thế: $_existingStoragePath');
              await FirebaseService.instance.deleteStorageFileOnly(
                storagePath: _existingStoragePath!,
              );
            } catch (cleanupErr) {
              debugPrint('[AddEditScreen] Lưu ý dọn dẹp tệp cũ: $cleanupErr');
            }
          }
        }
        // ====================================================================
        // TRƯỜNG HỢP 2: CHỈ SỬA METADATA (TIÊU ĐỀ, MÔN HỌC, DANH MỤC, GHI CHÚ)
        // GIỮ NGUYÊN STORAGE_PATH, FILE_NAME, FILE_SIZE - KHÔNG UPLOAD - KHÔNG XÓA
        // ====================================================================
        else if (_existingStoragePath != null && _existingStoragePath!.isNotEmpty) {
          // [SAVE-5] Bắt đầu lưu metadata
          debugPrint('[SAVE-5] Bắt đầu lưu metadata (Giữ nguyên tệp Storage)');

          if (user != null) {
            final supabaseDoc = SupabaseDocumentModel(
              id: docUuid,
              ownerId: ownerId!,
              title: _titleController.text.trim(),
              description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              subject: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
              categoryId: _selectedCategoryId!,
              fileName: _existingFileName ?? p.basename(_existingStoragePath!),
              fileType: _existingFileType ?? 'file',
              fileSize: _existingFileSize ?? 0,
              storagePath: _existingStoragePath!,
              locationName: _locationName,
              building: _building,
              floor: _floor,
              shelf: _shelf,
              physicalLocation: _physicalLocation,
              latitude: _latitude,
              longitude: _longitude,
              locationNotes: _locationNotes,
              isAvailableForBorrow: _isBorrowable,
              isDiscoverable: _isDiscoverable,
              isBorrowable: _isBorrowable,
              createdAt: originalDoc.createdDate,
              updatedAt: now,
            );
            await SupabaseService.instance.updateDocumentMetadata(
              id: docUuid,
              data: supabaseDoc.toJsonForUpdate(includeDiscoverability: originalDoc.isOwner),
            );
          }


          final updatedDoc = originalDoc.copyWith(
            title: _titleController.text.trim(),
            subject: _subjectController.text.trim(),
            categoryId: _selectedCategoryId!,
            filePathOrUrl: _existingStoragePath!,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tags: _tags,
            priority: _selectedPriority,
            locationName: _locationName,
            building: _building,
            floor: _floor,
            shelf: _shelf,
            physicalLocation: _physicalLocation,
            latitude: _latitude,
            longitude: _longitude,
            locationNotes: _locationNotes,
            isAvailableForBorrow: _isBorrowable,
            isDiscoverable: _isDiscoverable,
            isBorrowable: _isBorrowable,
            updatedDate: now,
          );
          await provider.updateDocument(updatedDoc);
          savedDocResult = updatedDoc;

          // [SAVE-6] Lưu metadata thành công
          debugPrint('[SAVE-6] Lưu metadata thành công');
        }
        // ====================================================================
        // TRƯỜNG HỢP 3: TÀI LIỆU LÀ LIÊN KẾT WEB HOẶC GHI CHÚ
        // ====================================================================
        else {
          final webPath = webUrl.isNotEmpty ? webUrl : (originalDoc.filePathOrUrl ?? '');

          // [SAVE-5] Bắt đầu lưu metadata
          debugPrint('[SAVE-5] Bắt đầu lưu metadata (Liên kết Web/Ghi chú)');

          if (user != null) {
            final supabaseDoc = SupabaseDocumentModel(
              id: docUuid,
              ownerId: ownerId!,
              title: _titleController.text.trim(),
              description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              subject: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
              categoryId: _selectedCategoryId!,
              fileName: webUrl.isNotEmpty ? 'Liên kết Web' : (_existingFileName ?? 'Tài liệu ghi chú'),
              fileType: webUrl.isNotEmpty ? 'link' : 'note',
              fileSize: 0,
              storagePath: webPath,
              locationName: _locationName,
              building: _building,
              floor: _floor,
              shelf: _shelf,
              physicalLocation: _physicalLocation,
              latitude: _latitude,
              longitude: _longitude,
              locationNotes: _locationNotes,
              isAvailableForBorrow: _isBorrowable,
              isDiscoverable: _isDiscoverable,
              isBorrowable: _isBorrowable,
              createdAt: originalDoc.createdDate,
              updatedAt: now,
            );
            await SupabaseService.instance.updateDocumentMetadata(
              id: docUuid,
              data: supabaseDoc.toJsonForUpdate(includeDiscoverability: originalDoc.isOwner),
            );
          }


          final updatedDoc = originalDoc.copyWith(
            title: _titleController.text.trim(),
            subject: _subjectController.text.trim(),
            categoryId: _selectedCategoryId!,
            filePathOrUrl: webPath.isEmpty ? null : webPath,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tags: _tags,
            priority: _selectedPriority,
            locationName: _locationName,
            building: _building,
            floor: _floor,
            shelf: _shelf,
            physicalLocation: _physicalLocation,
            latitude: _latitude,
            longitude: _longitude,
            locationNotes: _locationNotes,
            isAvailableForBorrow: _isBorrowable,
            isDiscoverable: _isDiscoverable,
            isBorrowable: _isBorrowable,
            updatedDate: now,
          );
          await provider.updateDocument(updatedDoc);
          savedDocResult = updatedDoc;

          // [SAVE-6] Lưu metadata thành công
          debugPrint('[SAVE-6] Lưu metadata thành công');
        }
      } else {
        // ====================================================================
        // THÊM MỚI TÀI LIỆU
        // ====================================================================
        final newId = const Uuid().v4();
        final docUuid = SupabaseDocumentModel.toValidUuid(newId);

        if (_newSelectedFilePath != null) {
          final newFile = (!kIsWeb && !_newSelectedFilePath!.startsWith('web_upload://'))
              ? File(_newSelectedFilePath!)
              : null;
          final newFileName = _newSelectedFileName ?? p.basename(_newSelectedFilePath!);
          final newExtension = p.extension(newFileName).toLowerCase();
          final newFileType = newExtension.replaceFirst('.', '').trim();
          final newFileSize = _newSelectedFileSize ??
              (_newSelectedFileBytes?.length ?? (newFile != null ? await newFile.length() : 0));
          final newContentType = _contentTypeForExtension(newExtension);

          // [SAVE-3] Bắt đầu upload
          debugPrint('[SAVE-3] Bắt đầu upload: $newFileName ($newFileSize bytes)');
          final storagePath = await FirebaseService.instance.uploadDocument(
            documentId: newId,
            file: newFile,
            fileBytes: _newSelectedFileBytes,
            fileName: newFileName,
            contentType: newContentType,
            onProgress: (progress) {
              if (mounted) setState(() => _uploadProgress = progress);
            },
          );
          newlyUploadedStoragePath = storagePath;

          // [SAVE-4] Upload thành công
          debugPrint('[SAVE-4] Upload thành công: path=$storagePath');
          if (mounted) setState(() => _uploadProgress = null);

          // [SAVE-5] Bắt đầu lưu metadata
          debugPrint('[SAVE-5] Bắt đầu lưu metadata (ID: $docUuid)');
          if (user != null) {
            final supabaseDoc = SupabaseDocumentModel(
              id: docUuid,
              ownerId: ownerId!,
              title: _titleController.text.trim(),
              description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              subject: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
              categoryId: _selectedCategoryId!,
              fileName: newFileName,
              fileType: newFileType.isEmpty ? 'bin' : newFileType,
              fileSize: newFileSize,
              storagePath: storagePath,
              locationName: _locationName,
              building: _building,
              floor: _floor,
              shelf: _shelf,
              physicalLocation: _physicalLocation,
              latitude: _latitude,
              longitude: _longitude,
              locationNotes: _locationNotes,
              isAvailableForBorrow: _isBorrowable,
              isDiscoverable: _isDiscoverable,
              isBorrowable: _isBorrowable,
              createdAt: now,
              updatedAt: now,
            );
            await SupabaseService.instance.insertDocumentMetadata(supabaseDoc);
          }


          final newDoc = DocumentModel(
            id: newId,
            title: _titleController.text.trim(),
            subject: _subjectController.text.trim(),
            categoryId: _selectedCategoryId!,
            filePathOrUrl: storagePath,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tags: _tags,
            priority: _selectedPriority,
            locationName: _locationName,
            building: _building,
            floor: _floor,
            shelf: _shelf,
            physicalLocation: _physicalLocation,
            latitude: _latitude,
            longitude: _longitude,
            locationNotes: _locationNotes,
            isAvailableForBorrow: _isBorrowable,
            isDiscoverable: _isDiscoverable,
            isBorrowable: _isBorrowable,
            ownerEmail: user?.email,
            ownerName: user?.displayName,
            createdDate: now,
            updatedDate: now,
          );
          await provider.addDocument(newDoc);
          savedDocResult = newDoc;

          // [SAVE-6] Lưu metadata thành công
          debugPrint('[SAVE-6] Lưu metadata thành công');
        } else {
          // Web Link hoặc Note mới
          final webPath = webUrl;

          // [SAVE-5] Bắt đầu lưu metadata (Liên kết Web/Ghi chú mới)
          debugPrint('[SAVE-5] Bắt đầu lưu metadata (Liên kết Web/Ghi chú mới)');

          if (user != null) {
            final supabaseDoc = SupabaseDocumentModel(
              id: docUuid,
              ownerId: ownerId!,
              title: _titleController.text.trim(),
              description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              subject: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
              categoryId: _selectedCategoryId!,
              fileName: webPath.isNotEmpty ? 'Liên kết Web' : 'Tài liệu ghi chú',
              fileType: webPath.isNotEmpty ? 'link' : 'note',
              fileSize: 0,
              storagePath: webPath,
              locationName: _locationName,
              building: _building,
              floor: _floor,
              shelf: _shelf,
              physicalLocation: _physicalLocation,
              latitude: _latitude,
              longitude: _longitude,
              locationNotes: _locationNotes,
              isAvailableForBorrow: _isBorrowable,
              isDiscoverable: _isDiscoverable,
              isBorrowable: _isBorrowable,
              createdAt: now,
              updatedAt: now,
            );
            await SupabaseService.instance.insertDocumentMetadata(supabaseDoc);
          }


          final newDoc = DocumentModel(
            id: newId,
            title: _titleController.text.trim(),
            subject: _subjectController.text.trim(),
            categoryId: _selectedCategoryId!,
            filePathOrUrl: webPath.isNotEmpty ? webPath : null,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            tags: _tags,
            priority: _selectedPriority,
            locationName: _locationName,
            building: _building,
            floor: _floor,
            shelf: _shelf,
            physicalLocation: _physicalLocation,
            latitude: _latitude,
            longitude: _longitude,
            locationNotes: _locationNotes,
            isAvailableForBorrow: _isBorrowable,
            isDiscoverable: _isDiscoverable,
            isBorrowable: _isBorrowable,
            ownerEmail: user?.email,
            ownerName: user?.displayName,
            createdDate: now,
            updatedDate: now,
          );
          await provider.addDocument(newDoc);
          savedDocResult = newDoc;

          // [SAVE-6] Lưu metadata thành công
          debugPrint('[SAVE-6] Lưu metadata thành công');
        }
      }

      // [SAVE-7] Hoàn tất
      debugPrint('[SAVE-7] Hoàn tất toàn bộ quy trình lưu tài liệu');
      if (mounted) {
        final isCloud = FirebaseService.instance.currentUser != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Đã cập nhật tài liệu thành công${isCloud ? ' (Đồng bộ Supabase & Storage)' : ''}'
                  : 'Đã thêm tài liệu mới${isCloud ? ' (Đồng bộ Supabase & Storage)' : ''}',
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.of(context).pop(savedDocResult);
      }
    } catch (e, stackTrace) {
      debugPrint('[SAVE-ERROR] Lỗi trong quá trình lưu tài liệu: $e');
      debugPrint('[SAVE-ERROR] StackTrace: $stackTrace');

      // Rollback file vừa upload nếu metadata insert thất bại
      if (newlyUploadedStoragePath != null && newlyUploadedStoragePath.isNotEmpty) {
        debugPrint('[ROLLBACK] Bắt đầu rollback xóa tệp vừa upload: $newlyUploadedStoragePath');
        try {
          await SupabaseService.instance
              .deleteStorageFile(newlyUploadedStoragePath)
              .timeout(const Duration(seconds: 15));
          debugPrint('[ROLLBACK] Đã rollback xóa tệp an toàn thành công');
        } catch (rollbackErr) {
          debugPrint('[ROLLBACK] Lỗi khi dọn dẹp rollback tệp: $rollbackErr');
        }
      }

      if (mounted) {
        final cleanMsg = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('StateError: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lưu tài liệu: $cleanMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadProgress = null;
        });
      }
      debugPrint('============================================================');
    }
  }

  String _contentTypeForExtension(String extension) {
    const types = {
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.txt': 'text/plain',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
    };
    return types[extension] ?? 'application/octet-stream';
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: const Text(
          'Xác nhận xóa tài liệu',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${widget.document?.title}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Đang xóa "${widget.document?.title ?? 'tài liệu'}"...'),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      try {
        await context.read<DocumentProvider>().deleteDocument(
          widget.document!.id,
          storagePath: widget.document!.filePathOrUrl,
          document: widget.document,
        );
        if (mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Đã xóa tài liệu thành công (Storage & Supabase)'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (err) {
        if (mounted) {
          messenger.hideCurrentSnackBar();
          final cleanMsg = err
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('StateError: ', '');
          messenger.showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa tài liệu: $cleanMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawCategories = context.watch<DocumentProvider>().categories;
    final categories = rawCategories.isNotEmpty ? rawCategories : CategoryModel.defaultCategories;

    if (_selectedCategoryId == null || !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.first.id;
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
            border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: SafeArea(
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                _isEditMode
                    ? (widget.document?.isEditor == true ? 'Chỉnh sửa (Editor)' : 'Chỉnh sửa tài liệu')
                    : 'Thêm tài liệu mới',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              actions: [
                if (_isEditMode && (widget.document?.canDelete ?? true))
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    tooltip: 'Xóa tài liệu',
                    onPressed: _isSaving ? null : _handleDelete,
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _uploadProgress == null
                          ? (_isSaving ? 'Đang lưu...' : 'Lưu')
                          : 'Đang tải ${(_uploadProgress! * 100).round()}%',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer.form(
          maxWidth: 740,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Banner thông báo nếu đang trong vai trò Editor
                if (widget.document?.isEditor == true) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bạn đang chỉnh sửa với quyền Editor. Bạn có thể cập nhật tiêu đề, môn học, danh mục và ghi chú (tệp gốc được bảo vệ).',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Khối thông tin học tập
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Thông tin học tập',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tiêu đề tài liệu
                TextFormField(
                  controller: _titleController,
                  maxLength: AppConstants.titleMaxLength,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề tài liệu *',
                    hintText: 'Ví dụ: Đề cương Giải tích 1 kì 2026',
                    prefixIcon: Icon(
                      Icons.title_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tiêu đề tài liệu';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Môn học (Subject)
                TextFormField(
                  controller: _subjectController,
                  maxLength: AppConstants.subjectMaxLength,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Môn học *',
                    hintText: 'Ví dụ: Toán cao cấp, Kiến trúc máy tính,...',
                    prefixIcon: Icon(
                      Icons.school_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên môn học';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Chọn Danh mục tài liệu
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCategoryId),
                  initialValue: categories.any((cat) => cat.id == _selectedCategoryId)
                      ? _selectedCategoryId
                      : categories.first.id,
                  dropdownColor: AppTheme.cardBackground,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Danh mục tài liệu *',
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  items: categories.map((CategoryModel cat) {
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(
                        cat.name,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoryId = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Khối thông tin đính kèm & Chi tiết
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tệp đính kèm & Liên kết',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vùng hiển thị / chọn tệp từ máy
                _buildFilePickerCard(),
                const SizedBox(height: 14),

                // Ô nhập liên kết web (TÁCH BIỆT HOÀN TOÀN KHỎI STORAGE PATH)
                TextFormField(
                  controller: _webUrlController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Liên kết Web (tùy chọn)',
                    hintText: 'https://... (dành cho tài liệu online hoặc website)',
                    prefixIcon: Icon(
                      Icons.language_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Ghi chú bổ sung (Notes)
                TextFormField(
                  controller: _notesController,
                  maxLength: AppConstants.notesMaxLength,
                  maxLines: 4,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú tóm tắt (tùy chọn)',
                    hintText: 'Nhập ghi chú tóm tắt nội dung tài liệu hoặc lưu ý quan trọng...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 50.0),
                      child: Icon(
                        Icons.notes_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Khối Thẻ phân loại (Tags)
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Thẻ phân loại (Tags)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TagInputWidget(
                  initialTags: _tags,
                  onTagsChanged: (tags) => setState(() => _tags = tags),
                ),
                const SizedBox(height: 20),

                // Khối Vị trí vật lý & Bản đồ
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Vị trí lưu trữ vật lý & Bản đồ (Thư viện / Tủ sách)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LocationPickerWidget(
                  initialLocation: _physicalLocation,
                  initialLocationName: _locationName,
                  initialBuilding: _building,
                  initialFloor: _floor,
                  initialShelf: _shelf,
                  initialLat: _latitude,
                  initialLng: _longitude,
                  initialNotes: _locationNotes,
                  onDetailedLocationChanged: ({
                    locationName,
                    building,
                    floor,
                    shelf,
                    physicalLocation,
                    lat,
                    lng,
                    notes,
                  }) {
                    _locationName = locationName;
                    _building = building;
                    _floor = floor;
                    _shelf = shelf;
                    _physicalLocation = physicalLocation;
                    _latitude = lat;
                    _longitude = lng;
                    _locationNotes = notes;
                  },
                ),
                const SizedBox(height: 12),

                // Tùy chọn Khám phá & Mượn tài liệu (EduVault Sharing)
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.explore_rounded, color: AppTheme.primaryColor, size: 20),
                        ),
                        title: const Text(
                          'Cho phép khám phá tài liệu',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Hiển thị tài liệu trong mục Khám phá công khai để người khác tìm kiếm (mặc định tắt)',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                        ),
                        value: _isDiscoverable,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: widget.document?.isEditor == true
                            ? null
                            : (val) => setState(() => _isDiscoverable = val),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.borderSubtle),
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent, size: 20),
                        ),
                        title: const Text(
                          'Cho phép mượn tài liệu',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Cho phép người dùng khác gửi yêu cầu mượn tài liệu này (mặc định tắt)',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                        ),
                        value: _isBorrowable,
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: widget.document?.isEditor == true
                            ? null
                            : (val) => setState(() {
                                _isBorrowable = val;
                              }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nút Lưu tài liệu lớn
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _uploadProgress == null
                          ? (_isSaving
                              ? 'Đang lưu dữ liệu...'
                              : (_isEditMode
                                  ? 'Cập nhật tài liệu'
                                  : 'Lưu tài liệu mới'))
                          : 'Đang tải ${(_uploadProgress! * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

/// Vẽ viền nét đứt mà không cần thêm package giao diện bên ngoài.
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 7, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
