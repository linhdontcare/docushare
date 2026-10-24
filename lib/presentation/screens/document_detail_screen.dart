// ==============================================================================
// PRESENTATION SCREEN: document_detail_screen.dart
// Màn hình xem chi tiết tài liệu học tập trong EduVault.
// Tách biệt rõ ràng:
// 1. Xem thông tin chi tiết tài liệu (Tiêu đề, Mô tả, Môn học, Danh mục, Tags, Chủ sở hữu, Ngày tạo, Tệp).
// 2. Thao tác "Xem file" (Mở xem trước nội dung tệp / Web URL).
// 3. Thao tác "Xem vị trí" (Hiển thị vị trí vật lý chi tiết và bản đồ OpenStreetMap).
// Thiết kế đáp ứng (Responsive): 1 cột trên Mobile, 2 cột trên Tablet / Desktop / Web.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_service.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/document_opener.dart';
import '../../domain/models/borrow_request_model.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/supabase_document_model.dart';
import '../providers/document_provider.dart';
import '../widgets/borrow_request_dialog.dart';
import '../widgets/map/eduvault_map_widget.dart';
import '../widgets/share_document_dialog.dart';
import 'add_edit_document_screen.dart';

class DocumentDetailScreen extends StatefulWidget {
  final DocumentModel document;

  const DocumentDetailScreen({
    super.key,
    required this.document,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late DocumentModel _document;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _locationSectionKey = GlobalKey();
  bool _isOpeningFile = false;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _loadFreshDocumentDetails();
  }

  /// Tải thông tin chi tiết đầy đủ (storage_path, mô tả, vị trí) từ Supabase
  /// nếu tài liệu được mở từ màn hình mượn hoặc khám phá
  Future<void> _loadFreshDocumentDetails() async {
    if (!SupabaseService.instance.isAvailable) return;
    try {
      final fresh = await SupabaseService.instance.fetchDocumentById(_document.id);
      if (fresh != null && mounted) {
        setState(() {
          _document = fresh.copyWith(
            userPermissionRole: _document.userPermissionRole,
          );
        });
      }
    } catch (e) {
      debugPrint('[DocumentDetailScreen] Lỗi khi nạp chi tiết tài liệu từ Supabase: $e');
    }
  }

  // Parse mã màu hex
  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  /// Mở xem trước tệp tài liệu
  Future<void> _handleOpenFile() async {
    if (_isOpeningFile) return;
    setState(() => _isOpeningFile = true);
    try {
      await DocumentOpener.openDocument(context, _document);
    } finally {
      if (mounted) setState(() => _isOpeningFile = false);
    }
  }

  /// Cuộn đến khối vị trí và bản đồ
  void _scrollToLocation() {
    if (_locationSectionKey.currentContext != null) {
      Scrollable.ensureVisible(
        _locationSectionKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Chuyển sang màn hình chỉnh sửa
  Future<void> _navigateToEdit() async {
    final updated = await Navigator.of(context).push<DocumentModel?>(
      MaterialPageRoute(
        builder: (ctx) => AddEditDocumentScreen(document: _document),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _document = updated);
    } else if (mounted) {
      // Tìm lại trong provider nếu có cập nhật
      final provider = context.read<DocumentProvider>();
      final fresh = provider.documents.firstWhere(
        (d) => d.id == _document.id,
        orElse: () => provider.sharedDocuments.firstWhere(
          (d) => d.id == _document.id,
          orElse: () => _document,
        ),
      );
      setState(() => _document = fresh);
    }
  }

  /// Xác nhận xóa tài liệu
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: const Text('Xác nhận xóa tài liệu', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${_document.title}"? Dữ liệu và tệp sẽ bị xóa vĩnh viễn.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa tài liệu'),
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
              Text('Đang xóa "${_document.title}"...'),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      try {
        await context.read<DocumentProvider>().deleteDocument(
          _document.id,
          storagePath: _document.filePathOrUrl,
          document: _document,
        );
        if (mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Đã xóa tài liệu thành công.'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Mở hộp thoại chia sẻ
  void _openShareDialog() {
    final user = FirebaseService.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập Google để chia sẻ tài liệu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => ShareDocumentDialog(
        document: _document,
        currentUserEmail: user.email!,
      ),
    );
  }

  /// Mở hộp thoại mượn tài liệu
  void _openBorrowDialog() {
    showDialog(
      context: context,
      builder: (_) => BorrowRequestDialog(document: _document),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    final categoryColor = _parseColor(doc.categoryColorHex, AppTheme.primaryColor);
    final docProvider = context.watch<DocumentProvider>();
    BorrowRequestModel? myBorrow;
    try {
      final docUuid = SupabaseDocumentModel.toValidUuid(doc.id);
      myBorrow = docProvider.myBorrowRequests.cast<BorrowRequestModel?>().firstWhere(
        (r) =>
            (r?.documentId == doc.id || r?.documentId == docUuid) &&
            (r?.isPending == true || r?.isCurrentlyBorrowed == true),
        orElse: () => null,
      );
    } catch (_) {}

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
              title: const Text(
                'Chi tiết tài liệu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              actions: [
                // Nút Mượn tài liệu nếu không phải Owner và chưa có yêu cầu mượn
                if (!doc.isOwner && (doc.isBorrowable || doc.isAvailableForBorrow) && myBorrow == null)
                  TextButton.icon(
                    onPressed: _openBorrowDialog,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppTheme.primaryColor),
                    label: const Text(
                      'Yêu cầu mượn',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),

                // Nút Trả sách nếu đang có lượt mượn approved
                if (!doc.isOwner && myBorrow != null && myBorrow.isCurrentlyBorrowed)
                  TextButton.icon(
                    onPressed: () async {
                      await docProvider.returnBorrowDocument(myBorrow!.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã trả tài liệu thành công.'), backgroundColor: AppTheme.primaryColor),
                        );
                      }
                    },
                    icon: const Icon(Icons.assignment_return_rounded, size: 18, color: Colors.amber),
                    label: const Text(
                      'Trả sách',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),

                // Nút Chia sẻ nếu là Owner
                if (doc.canShare)
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.cyanAccent),
                    tooltip: 'Chia sẻ tài liệu',
                    onPressed: _openShareDialog,
                  ),

                // Nút Chỉnh sửa nếu có quyền canEdit
                if (doc.canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                    tooltip: 'Chỉnh sửa tài liệu',
                    onPressed: _navigateToEdit,
                  ),

                // Nút Xóa nếu là Owner
                if (doc.canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    tooltip: 'Xóa tài liệu',
                    onPressed: _confirmDelete,
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 760;

          return ResponsiveContainer(
            maxWidth: 1100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cột trái: Thông tin tài liệu & Tệp tin
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBorrowStatusBanner(doc, myBorrow, docProvider),
                              _buildMainInfoCard(doc, categoryColor),
                              const SizedBox(height: 16),
                              _buildFileCard(doc),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Cột phải: Vị trí vật lý & Bản đồ số
                        Expanded(
                          flex: 2,
                          child: _buildLocationCard(doc),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mobile: 1 cột cuộn liền mạch
                        _buildBorrowStatusBanner(doc, myBorrow, docProvider),
                        _buildQuickActionButtons(doc),
                        const SizedBox(height: 16),
                        _buildMainInfoCard(doc, categoryColor),
                        const SizedBox(height: 16),
                        _buildFileCard(doc),
                        const SizedBox(height: 16),
                        _buildLocationCard(doc),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  /// Banner thông báo trạng thái mượn tài liệu (Đang mượn / Chờ duyệt / Có thể mượn)
  Widget _buildBorrowStatusBanner(DocumentModel doc, BorrowRequestModel? myBorrow, DocumentProvider docProvider) {
    if (doc.isOwner) return const SizedBox.shrink();

    if (myBorrow != null && myBorrow.isCurrentlyBorrowed) {
      final days = myBorrow.remainingDays;
      final dueStr = DateFormat('dd/MM/yyyy').format(myBorrow.dueAt);
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đang trong thời hạn mượn (Viewer tạm thời)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hạn trả: $dueStr (Còn $days ngày)',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.withValues(alpha: 0.2),
                foregroundColor: Colors.amber,
              ),
              onPressed: () async {
                await docProvider.returnBorrowDocument(myBorrow.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã trả tài liệu thành công.'), backgroundColor: AppTheme.primaryColor),
                  );
                }
              },
              child: const Text('Trả sách sớm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (myBorrow != null && myBorrow.isPending) {
      final reqStr = DateFormat('dd/MM/yyyy HH:mm').format(myBorrow.requestedAt);
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yêu cầu mượn đang chờ duyệt',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Thời hạn đăng ký: ${myBorrow.requestedDays} ngày • Gửi lúc $reqStr',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: () async {
                await docProvider.cancelBorrowRequest(myBorrow.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã hủy yêu cầu mượn.'), backgroundColor: AppTheme.primaryColor),
                  );
                }
              },
              child: const Text('Hủy yêu cầu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (!doc.isOwner && (doc.isBorrowable || doc.isAvailableForBorrow)) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài liệu cho phép mượn',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bạn có thể gửi yêu cầu mượn tài liệu này trong 1, 3, 7 hoặc 14 ngày.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _openBorrowDialog,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Yêu cầu mượn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Nút thao tác nhanh trên Mobile ("Xem file" & "Xem vị trí")
  Widget _buildQuickActionButtons(DocumentModel doc) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: doc.hasAttachment ? (_isOpeningFile ? null : _handleOpenFile) : null,
            icon: _isOpeningFile
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.visibility_rounded, size: 18),
            label: Text(
              _isOpeningFile ? 'Đang mở tệp...' : 'Xem file',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _scrollToLocation,
            icon: const Icon(Icons.place_rounded, size: 18),
            label: const Text(
              'Xem vị trí',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }

  /// Card thông tin cơ bản của tài liệu (Tiêu đề, Danh mục, Môn học, Tags, Mô tả, Chủ sở hữu)
  Widget _buildMainInfoCard(DocumentModel doc, Color categoryColor) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final createdStr = dateFormat.format(doc.createdDate);
    final updatedStr = dateFormat.format(doc.updatedDate);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng Badges: Danh mục, Phân quyền, Ưu tiên
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Badge Danh mục
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: categoryColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_outlined, size: 14, color: categoryColor),
                    const SizedBox(width: 5),
                    Text(
                      doc.categoryName ?? 'Chưa phân loại',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Phân quyền (Owner / Editor / Viewer)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                decoration: BoxDecoration(
                  color: doc.isOwner
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : (doc.isEditor
                          ? Colors.cyanAccent.withValues(alpha: 0.12)
                          : Colors.lightBlueAccent.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: doc.isOwner
                        ? AppTheme.primaryColor.withValues(alpha: 0.3)
                        : (doc.isEditor
                            ? Colors.cyanAccent.withValues(alpha: 0.3)
                            : Colors.lightBlueAccent.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      doc.isOwner
                          ? Icons.shield_rounded
                          : (doc.isEditor ? Icons.edit_outlined : Icons.visibility_outlined),
                      size: 13,
                      color: doc.isOwner
                          ? AppTheme.primaryColor
                          : (doc.isEditor ? Colors.cyanAccent : Colors.lightBlueAccent),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      doc.isOwner ? 'Chủ sở hữu' : (doc.isEditor ? 'Editor' : 'Viewer'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: doc.isOwner
                            ? AppTheme.primaryColor
                            : (doc.isEditor ? Colors.cyanAccent : Colors.lightBlueAccent),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Ưu tiên
              if (doc.priority.name != 'low')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: doc.priority.name == 'high'
                        ? Colors.red.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: doc.priority.name == 'high'
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    doc.priority.name == 'high' ? 'Ưu tiên cao' : 'Ưu tiên trung bình',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: doc.priority.name == 'high' ? Colors.redAccent : Colors.orangeAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Tiêu đề tài liệu (H1)
          SelectableText(
            doc.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppTheme.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),

          // Môn học
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Môn học: ${doc.subject.isNotEmpty ? doc.subject : "Chưa chỉ định"}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chủ sở hữu
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: Colors.cyanAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  doc.isOwner
                      ? 'Chủ sở hữu: Bạn (Tài khoản hiện tại)'
                      : 'Chủ sở hữu: ${doc.ownerName ?? doc.ownerEmail ?? "Người dùng khác"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ngày tạo và cập nhật (Sử dụng Wrap chống tràn RenderFlex)
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                      ),
                    ),
                    TextSpan(
                      text: 'Ngày tạo: $createdStr',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (createdStr != updatedStr)
                Text(
                  '• Đã sửa: $updatedStr',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
            ],
          ),
          const Divider(height: 28, color: AppTheme.borderSubtle),

          // Mô tả / Ghi chú
          const Text(
            'Mô tả & Ghi chú:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            (doc.notes != null && doc.notes!.trim().isNotEmpty)
                ? doc.notes!.trim()
                : 'Không có ghi chú bổ sung cho tài liệu này.',
            style: TextStyle(
              fontSize: 14,
              color: (doc.notes != null && doc.notes!.trim().isNotEmpty)
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),

          // Thẻ phân loại (Tags)
          const Text(
            'Thẻ phân loại (Tags):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (doc.tags.isEmpty)
            const Text(
              'Chưa gắn thẻ phân loại.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: doc.tags.map((tag) {
                final cleanTag = tag.replaceAll('#', '').trim();
                final isSelected = context.watch<DocumentProvider>().selectedTags.any(
                      (t) => t.toLowerCase() == cleanTag.toLowerCase(),
                    );
                return InkWell(
                  onTap: () {
                    context.read<DocumentProvider>().addTagFilter(cleanTag);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.tag_rounded,
                          size: 12,
                          color: isSelected ? Colors.white : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '#$cleanTag',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Card thông tin tệp tin & Nút hành động "Xem file"
  Widget _buildFileCard(DocumentModel doc) {
    final hasFile = doc.hasAttachment;
    final path = doc.filePathOrUrl ?? '';
    final isLink = doc.isWebLink;
    final fileName = hasFile ? (isLink ? path : p.basename(path)) : 'Không có tệp đính kèm';
    final fileExt = hasFile ? (isLink ? 'URL' : p.extension(path).toUpperCase().replaceAll('.', '')) : '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : AppTheme.borderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLink
                      ? Icons.link_rounded
                      : (fileExt == 'PDF' ? Icons.picture_as_pdf_rounded : Icons.description_rounded),
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLink ? 'Liên kết trực tuyến' : 'Tệp tài liệu đính kèm',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (fileExt.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fileExt,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Nút Xem file chính
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: hasFile ? AppTheme.primaryColor : Colors.grey.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: hasFile ? (_isOpeningFile ? null : _handleOpenFile) : null,
              icon: _isOpeningFile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isLink ? Icons.open_in_new_rounded : Icons.visibility_rounded, size: 18),
              label: Text(
                _isOpeningFile
                    ? 'Đang mở tài liệu...'
                    : (hasFile ? (isLink ? 'Mở liên kết web' : 'Xem file / Mở tệp') : 'Không có tệp đính kèm'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card Vị trí vật lý & Bản đồ số OpenStreetMap
  Widget _buildLocationCard(DocumentModel doc) {
    final hasLoc = doc.hasPhysicalLocation;

    return Container(
      key: _locationSectionKey,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasLoc ? Colors.amber.withValues(alpha: 0.4) : AppTheme.borderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header khối vị trí
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vị trí vật lý & Bản đồ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Thông tin vị trí lưu trữ tài liệu thực tế',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (doc.canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 20, color: Colors.amber),
                  tooltip: 'Cập nhật vị trí',
                  onPressed: _navigateToEdit,
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasLoc) ...[
            // Trạng thái nhắc nhở khi chưa lưu vị trí chi tiết
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tài liệu này chưa được gán vị trí vật lý cụ thể trong thư viện hoặc khuôn viên.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                  if (doc.canEdit) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.amber,
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _navigateToEdit,
                      child: const Text('Ghim vị trí', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Chi tiết vị trí vật lý
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationInfoItem(
                    icon: Icons.account_balance_outlined,
                    label: 'Cơ sở / Thư viện',
                    value: doc.locationName ?? doc.displayLocationName,
                  ),
                  if (doc.building != null && doc.building!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildLocationInfoItem(
                      icon: Icons.business_outlined,
                      label: 'Tòa nhà',
                      value: doc.building!,
                    ),
                  ],
                  if (doc.floor != null && doc.floor!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildLocationInfoItem(
                      icon: Icons.layers_outlined,
                      label: 'Tầng',
                      value: doc.floor!,
                    ),
                  ],
                  if (doc.shelf != null && doc.shelf!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildLocationInfoItem(
                      icon: Icons.shelves,
                      label: 'Phòng / Kệ sách',
                      value: doc.shelf!,
                    ),
                  ],
                  if (doc.locationNotes != null && doc.locationNotes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildLocationInfoItem(
                      icon: Icons.info_outline_rounded,
                      label: 'Lưu ý mượn',
                      value: doc.locationNotes!,
                    ),
                  ],
                  if (doc.hasCoordinates) ...[
                    const SizedBox(height: 8),
                    _buildLocationInfoItem(
                      icon: Icons.my_location_rounded,
                      label: 'Tọa độ GPS',
                      value: '${doc.latitude!.toStringAsFixed(4)}° N, ${doc.longitude!.toStringAsFixed(4)}° E',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      context.read<DocumentProvider>().setLocationFilter(
                            doc.locationName ?? doc.displayLocationName,
                          );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.filter_alt_rounded, size: 16),
                    label: Text(
                      'Lọc tài liệu tại ${doc.displayLocationName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Bản đồ số thu nhỏ (Minimap) OpenStreetMap - LUÔN LUÔN HIỂN THỊ
          EduVaultMapWidget(
            latitude: doc.latitude,
            longitude: doc.longitude,
            locationTitle: hasLoc ? doc.displayLocationName : 'Khuôn viên trường (Tham chiếu)',
            locationSubtitle: hasLoc ? doc.formattedLocationAddress : null,
            height: 260,
            onTapSetLocation: doc.canEdit ? _navigateToEdit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.amber),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
