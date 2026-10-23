import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/library_sync.dart';
import '../../auth/data/auth_service.dart';
import '../../tagging/data/tag_service.dart';
import '../data/document_service.dart';
import '../domain/models/document_model.dart';
import 'widgets/document_form_dialog.dart';

/// Màn hình Quản lý Tài liệu (Documents Feature)
/// Dữ liệu thật: Supabase Database (bảng "Documents") & Storage (bucket 'documents').
/// Chức năng: xem / tìm kiếm / lọc theo danh mục + tag, tải lên, sửa, xóa
/// (chỉ chủ sở hữu mới sửa/xóa được - phân quyền ở tầng app).
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _service = DocumentService.instance;
  final _tagService = TagService.instance;
  final _searchController = TextEditingController();

  List<DocumentModel> _documents = [];
  List<String> _allTagNames = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _categoryFilter = 'Tất cả';
  String? _tagFilter;

  @override
  void initState() {
    super.initState();
    _load();
    // Đồng bộ với module Tagging: thêm/đổi tên/xóa tag là tự cập nhật.
    LibrarySync.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    LibrarySync.instance.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final docs = await _service.fetchDocuments();
      final tags = await _tagService.fetchTagsWithCounts();
      if (mounted) {
        setState(() {
          _documents = docs;
          _allTagNames = tags.map((t) => t.name).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<DocumentModel> get _filtered {
    final q = _normalize(_search);
    return _documents.where((d) {
      final matchSearch = q.isEmpty ||
          _normalize(d.title).contains(q) ||
          _normalize(d.author).contains(q) ||
          _normalize(d.description).contains(q) ||
          _normalize(d.fileName).contains(q) ||
          d.tagNames.any((t) => _normalize(t).contains(q));
      final matchCat =
          _categoryFilter == 'Tất cả' || d.category == _categoryFilter;
      final matchTag = _tagFilter == null || d.tagNames.contains(_tagFilter);
      return matchSearch && matchCat && matchTag;
    }).toList();
  }

  /// Bỏ dấu tiếng Việt + chuyển chữ thường để tìm kiếm gõ không dấu vẫn khớp
  /// (vd: gõ "tai lieu" vẫn tìm thấy "Tài liệu", "kiem thu" khớp tên file PDF).
  String _normalize(String input) {
    var s = input.toLowerCase();
    const groups = {
      'a': 'àáảãạăằắẳẵặâầấẩẫậ',
      'e': 'èéẻẽẹêềếểễệ',
      'i': 'ìíỉĩị',
      'o': 'òóỏõọôồốổỗộơờớởỡợ',
      'u': 'ùúủũụưừứửữự',
      'y': 'ỳýỷỹỵ',
      'd': 'đ',
    };
    groups.forEach((base, chars) {
      for (final ch in chars.split('')) {
        s = s.replaceAll(ch, base);
      }
    });
    return s;
  }

  Future<void> _openForm({DocumentModel? existing}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      _snack('Bạn cần đăng nhập trước khi tải lên / sửa tài liệu.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DocumentFormDialog(
        ownerId: user.id,
        ownerEmail: user.email,
        existing: existing,
        tagSuggestions: _allTagNames,
      ),
    );
    if (ok == true) {
      _snack(existing == null
          ? 'Đã tải lên tài liệu thành công.'
          : 'Đã cập nhật tài liệu.');
      await _load();
    }
  }

  Future<void> _delete(DocumentModel doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa tài liệu'),
        content: Text('Bạn có chắc muốn xóa "${doc.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteDocument(doc.id);
      _snack('Đã xóa tài liệu.');
      await _load();
    } catch (e) {
      _snack('Xóa thất bại: $e');
    }
  }

  Future<void> _openFile(DocumentModel doc) async {
    if (doc.fileUrl.isEmpty) {
      _snack('Tài liệu này chưa có file đính kèm.');
      return;
    }
    final uri = Uri.tryParse(doc.fileUrl);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Giáo trình':
        return Icons.menu_book;
      case 'Đề thi':
        return Icons.quiz_outlined;
      case 'Slide bài giảng':
        return Icons.slideshow_outlined;
      case 'Báo cáo đồ án':
        return Icons.assignment_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = AuthService.instance.currentUser?.id;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý Tài liệu',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kho lưu trữ giáo trình, đề thi, bài giảng và tài liệu nghiên cứu.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Tải lên'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm theo tên tài liệu, tác giả, tag...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Wrap(
              spacing: 8,
              children: ['Tất cả', ...DocumentModel.categories]
                  .map((c) => FilterChip(
                        label: Text(c),
                        selected: _categoryFilter == c,
                        onSelected: (_) => setState(() => _categoryFilter = c),
                      ))
                  .toList(),
            ),
            if (_allTagNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _allTagNames
                    .map((t) => FilterChip(
                          label: Text('#$t'),
                          selected: _tagFilter == t,
                          onSelected: (_) => setState(
                              () => _tagFilter = _tagFilter == t ? null : t),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: AppConstants.paddingMedium),
            Expanded(child: _buildBody(theme, currentUserId)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, String? currentUserId) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'Không tải được dữ liệu tài liệu.\nKiểm tra cấu hình Supabase (URL/anon key + đã chạy schema.sql chưa).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final docs = _filtered;
    if (docs.isEmpty) {
      return const Center(
        child: Text('Chưa có tài liệu nào khớp. Bấm "Tải lên" để thêm mới.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) =>
            _buildDocCard(theme, docs[i], docs[i].isOwnedBy(currentUserId)),
      ),
    );
  }

  Widget _buildDocCard(ThemeData theme, DocumentModel doc, bool isOwner) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFile(doc),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Icon(_categoryIcon(doc.category),
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (doc.author.isNotEmpty) doc.author,
                        if (doc.fileName.isNotEmpty) doc.fileName,
                        'Đăng bởi ${doc.ownerEmail}',
                      ].join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (doc.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        doc.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                                AppConstants.radiusSmall),
                          ),
                          child: Text(
                            doc.category,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        ...doc.tagNames.map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusSmall),
                              ),
                              child: Text(
                                '#$t',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )),
                        if (isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSmall),
                            ),
                            child: Text(
                              'Của tôi',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Tùy chọn',
                onSelected: (v) {
                  if (v == 'open') _openFile(doc);
                  if (v == 'edit') _openForm(existing: doc);
                  if (v == 'delete') _delete(doc);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'open', child: Text('Mở file đính kèm')),
                  if (isOwner) ...[
                    const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
