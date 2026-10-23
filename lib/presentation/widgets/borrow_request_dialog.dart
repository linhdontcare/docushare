// ==============================================================================
// PRESENTATION WIDGET: borrow_request_dialog.dart
// 1. BorrowRequestDialog: Hộp thoại tạo yêu cầu mượn tài liệu (1, 3, 7, 14 ngày)
// 2. BorrowManagementModal: Trung tâm Quản lý Yêu cầu mượn & trả tài liệu (TH2)
//    - Tab 1: Yêu cầu nhận được (Owner: Chấp nhận, Từ chối, Nhận lại sách)
//    - Tab 2: Yêu cầu đã gửi (Borrower: Hủy khi pending, Xem tài liệu & Trả sớm khi approved)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/borrow_request_model.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/supabase_document_model.dart';
import '../providers/document_provider.dart';
import '../providers/user_provider.dart';
import '../screens/document_detail_screen.dart';

/// Hộp thoại yêu cầu mượn tài liệu
class BorrowRequestDialog extends StatefulWidget {
  final DocumentModel document;

  const BorrowRequestDialog({super.key, required this.document});

  @override
  State<BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<BorrowRequestDialog> {
  int _borrowDays = 7; // Mặc định 7 ngày
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final userProvider = context.read<UserProvider>();
    final docProvider = context.read<DocumentProvider>();
    final profile = userProvider.profile;
    final currentUser = FirebaseService.instance.currentUser;

    if (profile == null && currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập trước khi gửi yêu cầu mượn tài liệu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 1. Kiểm tra tài liệu của chính mình
    if (widget.document.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể gửi yêu cầu mượn tài liệu của chính mình.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Kiểm tra tài liệu có cho phép mượn không
    if (!widget.document.isBorrowable && !widget.document.isAvailableForBorrow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài liệu này hiện không cho phép mượn.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Kiểm tra xem đã có yêu cầu pending hoặc approved đang hoạt động cho tài liệu này chưa
    final docUuid = SupabaseDocumentModel.toValidUuid(widget.document.id);
    final alreadyActive = docProvider.myBorrowRequests.any((r) =>
        (r.documentId == widget.document.id || r.documentId == docUuid) &&
        (r.isPending || (r.isApproved && !r.isReturned && !r.isExpired)));
    if (alreadyActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã có một yêu cầu đang chờ duyệt hoặc một lượt mượn đang hoạt động cho tài liệu này.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dueDate = DateTime.now().add(Duration(days: _borrowDays));
      final requesterId = profile?.id ?? '';
      final requesterEmail = profile?.email ?? currentUser?.email ?? '';
      final requesterName = profile?.displayName ?? currentUser?.displayName;

      await docProvider.createBorrowRequest(
        documentId: widget.document.id,
        documentTitle: widget.document.title,
        requesterId: requesterId,
        requesterEmail: requesterEmail,
        requesterName: requesterName,
        ownerId: widget.document.ownerEmail ?? requesterId,
        dueDate: dueDate,
        requestedDays: _borrowDays,
        message: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi yêu cầu mượn tài liệu "${widget.document.title}" ($_borrowDays ngày) thành công!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi yêu cầu mượn: $cleanMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bookmark_add_rounded, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Yêu cầu mượn tài liệu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Môn học: ${widget.document.subject}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (widget.document.hasPhysicalLocation) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place_rounded, size: 13, color: Colors.amber),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.document.displayLocationName,
                      style: const TextStyle(fontSize: 11.5, color: Colors.amber, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Chọn thời hạn mượn: 3, 7, 14, 30 ngày
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thời hạn mượn:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                Text(
                  'Hạn trả: ${DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: _borrowDays)))}',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [3, 7, 14, 30].map((days) {
                final isSelected = _borrowDays == days;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: ChoiceChip(
                      label: Text('$days ngày', style: const TextStyle(fontSize: 11.5)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      backgroundColor: AppTheme.scaffoldBackground,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _borrowDays = days),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Lời nhắn / Ghi chú
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Lời nhắn gửi chủ sở hữu (tùy chọn)',
                hintText: 'Ví dụ: Mình muốn mượn để ôn tập giữa kỳ môn học này...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                filled: true,
                fillColor: AppTheme.scaffoldBackground,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _submitRequest,
          icon: _isSubmitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu'),
        ),
      ],
    );
  }
}

/// Modal quản lý danh sách yêu cầu mượn & trả tài liệu
class BorrowManagementModal extends StatefulWidget {
  const BorrowManagementModal({super.key});

  @override
  State<BorrowManagementModal> createState() => _BorrowManagementModalState();
}

class _BorrowManagementModalState extends State<BorrowManagementModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().profile;
      if (user != null) {
        context.read<DocumentProvider>().fetchBorrowRequests(user.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      backgroundColor: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Quản lý Mượn & Trả Tài liệu',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Yêu cầu nhận được'),
                      if (provider.incomingBorrowRequests.any((r) => r.isPending)) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '${provider.incomingBorrowRequests.where((r) => r.isPending).length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Yêu cầu mượn'),
                      const SizedBox(width: 6),
                      Text(
                        '(${provider.myBorrowRequests.where((r) => r.isPending).length})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Đang mượn'),
                      const SizedBox(width: 6),
                      Text(
                        '(${provider.myBorrowRequests.where((r) => r.isCurrentlyBorrowed).length})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Lịch sử mượn/trả'),
                      const SizedBox(width: 6),
                      Text(
                        '(${provider.myBorrowRequests.where((r) => !r.isPending && !r.isCurrentlyBorrowed).length})',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Incoming requests (Chủ sở hữu nhận được)
                  _buildRequestList(
                    requests: provider.incomingBorrowRequests,
                    isIncoming: true,
                    dateFormat: dateFormat,
                    provider: provider,
                  ),

                  // Tab 2: Yêu cầu mượn (Đang chờ duyệt hoặc bị từ chối)
                  _buildRequestList(
                    requests: provider.myBorrowRequests.where((r) => r.isPending).toList(),
                    isIncoming: false,
                    dateFormat: dateFormat,
                    provider: provider,
                    emptyMessage: 'Bạn không có yêu cầu mượn nào đang chờ duyệt.',
                  ),

                  // Tab 3: Đang mượn (Approved, còn hạn, chưa trả)
                  _buildRequestList(
                    requests: provider.myBorrowRequests.where((r) => r.isCurrentlyBorrowed).toList(),
                    isIncoming: false,
                    dateFormat: dateFormat,
                    provider: provider,
                    emptyMessage: 'Hiện bạn không có tài liệu nào đang mượn.',
                  ),

                  // Tab 4: Lịch sử mượn/trả (Đã trả, hết hạn, bị từ chối hoặc hủy)
                  _buildRequestList(
                    requests: provider.myBorrowRequests.where((r) => !r.isPending && !r.isCurrentlyBorrowed).toList(),
                    isIncoming: false,
                    dateFormat: dateFormat,
                    provider: provider,
                    emptyMessage: 'Chưa có lịch sử mượn hoặc trả tài liệu nào.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList({
    required List<BorrowRequestModel> requests,
    required bool isIncoming,
    required DateFormat dateFormat,
    required DocumentProvider provider,
    String? emptyMessage,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              emptyMessage ?? (isIncoming ? 'Chưa có yêu cầu mượn tài liệu nào gửi đến bạn.' : 'Bạn chưa gửi yêu cầu mượn tài liệu nào.'),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = requests[index];
        final statusColor = _statusColor(req.status, req.isOverdue);

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tên tài liệu & Trạng thái
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      req.documentTitle,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor, width: 0.8),
                    ),
                    child: Text(
                      req.statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Người mượn / Người sở hữu
              Text(
                isIncoming
                    ? 'Người mượn: ${req.borrowerName ?? req.borrowerEmail}'
                    : 'Chủ sở hữu: ${req.ownerName ?? req.ownerEmail ?? "EduVault User"}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 4),

              // Thông tin thời gian: Ngày gửi & Hạn mượn
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Gửi lúc: ${dateFormat.format(req.requestedAt)} (${req.requestedDays} ngày)',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        req.isApproved
                            ? 'Hạn trả: ${DateFormat('dd/MM/yyyy').format(req.dueAt)}${req.isCurrentlyBorrowed ? " (Còn ${req.remainingDays} ngày)" : ""}'
                            : 'Hạn trả dự kiến: ${DateFormat('dd/MM/yyyy').format(req.dueAt)}',
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),

              if (req.message != null && req.message!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lời nhắn: "${req.message}"',
                    style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppTheme.textPrimary),
                  ),
                ),
              ],

              // ================================================================
              // HÀNH ĐỘNG CHO TAB 1: YÊU CẦU NHẬN ĐƯỢC (OWNER)
              // ================================================================
              if (isIncoming && req.isPending) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      onPressed: () => provider.rejectBorrowRequest(req.id),
                      child: const Text('Từ chối', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                      onPressed: () => provider.approveBorrowRequest(req.id),
                      child: const Text('Chấp nhận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],

              if (isIncoming && req.isCurrentlyBorrowed) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: () => provider.returnBorrowDocument(req.id),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                    label: const Text('Đã nhận lại sách', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              // ================================================================
              // HÀNH ĐỘNG CHO TAB 2: YÊU CẦU ĐÃ GỬI (BORROWER)
              // ================================================================
              if (!isIncoming && req.isPending) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                    onPressed: () => provider.cancelBorrowRequest(req.id),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Hủy yêu cầu', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],

              if (!isIncoming && req.isCurrentlyBorrowed) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () => provider.returnBorrowDocument(req.id),
                      icon: const Icon(Icons.assignment_return_outlined, size: 14),
                      label: const Text('Trả tài liệu', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        navigator.pop(); // Đóng modal

                        // 1. Tìm trong provider documents hoặc sharedDocuments nếu đã có đầy đủ
                        DocumentModel? doc = provider.documents.cast<DocumentModel?>().firstWhere(
                          (d) => d?.id == req.documentId && (d?.hasAttachment ?? false),
                          orElse: () => null,
                        ) ?? provider.sharedDocuments.cast<DocumentModel?>().firstWhere(
                          (d) => d?.id == req.documentId && (d?.hasAttachment ?? false),
                          orElse: () => null,
                        );

                        // 2. Nếu chưa có hoặc thiếu file đính kèm, nạp trực tiếp từ Supabase
                        if (doc == null && SupabaseService.instance.isAvailable) {
                          doc = await SupabaseService.instance.fetchDocumentById(req.documentId);
                        }

                        // 3. Fallback an toàn nếu lỗi mạng
                        doc ??= DocumentModel(
                          id: req.documentId,
                          title: req.documentTitle,
                          subject: '',
                          categoryId: 'all',
                          userPermissionRole: 'viewer',
                          createdDate: req.requestedAt,
                          updatedDate: req.requestedAt,
                        );

                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => DocumentDetailScreen(document: doc!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded, size: 14),
                      label: const Text('Xem tài liệu', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String status, bool isOverdue) {
    if (isOverdue) return Colors.red;
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.grey;
      case 'returned':
        return Colors.blueGrey;
      case 'expired':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }
}
