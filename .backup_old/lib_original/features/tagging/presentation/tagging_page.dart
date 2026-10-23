import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/library_sync.dart';
import '../../documents/domain/models/document_model.dart';
import '../data/tag_service.dart';
import '../domain/models/tag_model.dart';

/// Màn hình Phân loại & Gắn thẻ Tag (Tagging Feature)
/// Dữ liệu thật từ Supabase: bảng "Tags" + "DocumentTags".
/// Chức năng: xem tag + số tài liệu, thêm / đổi tên / xóa tag,
/// bấm vào tag để xem các tài liệu đang gắn tag đó.
class TaggingPage extends StatefulWidget {
  const TaggingPage({super.key});

  @override
  State<TaggingPage> createState() => _TaggingPageState();
}

class _TaggingPageState extends State<TaggingPage> {
  final _service = TagService.instance;
  List<TagModel> _tags = [];
  bool _loading = true;
  String? _error;

  static const _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.warning,
    AppColors.success,
    AppColors.error,
    AppColors.primaryLight,
  ];

  @override
  void initState() {
    super.initState();
    _load();
    // Đồng bộ với module Documents: thêm/sửa/xóa tài liệu là tự cập nhật.
    LibrarySync.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    LibrarySync.instance.removeListener(_onDataChanged);
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
      final tags = await _service.fetchTagsWithCounts();
      if (mounted) {
        setState(() {
          _tags = tags;
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

  Future<void> _addTag() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _TagFormDialog(title: 'Thêm tag mới'),
    );
    if (name == null) return;
    try {
      await _service.createTag(name);
      _snack('Đã thêm tag #$name');
      await _load();
    } catch (e) {
      _snack('Thêm tag thất bại (tag đã tồn tại?): $e');
    }
  }

  Future<void> _renameTag(TagModel tag) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TagFormDialog(title: 'Đổi tên tag', initial: tag.name),
    );
    if (name == null || name == tag.name) return;
    try {
      await _service.renameTag(tag.id, name);
      _snack('Đã đổi tên tag thành #$name');
      await _load();
    } catch (e) {
      _snack('Đổi tên thất bại: $e');
    }
  }

  Future<void> _deleteTag(TagModel tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa tag'),
        content: Text(
          'Xóa tag #${tag.name}? Tag sẽ bị gỡ khỏi ${tag.documentCount} tài liệu '
          '(tài liệu vẫn còn nguyên).',
        ),
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
      await _service.deleteTag(tag.id);
      _snack('Đã xóa tag #${tag.name}');
      await _load();
    } catch (e) {
      _snack('Xóa tag thất bại: $e');
    }
  }

  Future<void> _showDocumentsWithTag(TagModel tag) async {
    // Hiện ở chính giữa màn hình (dialog) cho dễ nhìn thay vì bottom sheet.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tài liệu gắn tag #${tag.name}'),
        content: SizedBox(
          width: 560,
          child: FutureBuilder(
            future: _service.fetchDocumentsWithTag(tag.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) {
                return const Text('Chưa có tài liệu nào gắn tag này.');
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(docs[i].title),
                    subtitle: Text(docs[i].author.isNotEmpty
                        ? '${docs[i].category} • ${docs[i].author}'
                        : docs[i].category),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    dense: true,
                    onTap: () => _showDocumentDetail(docs[i]),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  /// Popup xem chi tiết 1 tài liệu trong danh sách gắn tag.
  void _showDocumentDetail(DocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Danh mục', doc.category),
              if (doc.author.isNotEmpty) _detailRow('Tác giả', doc.author),
              _detailRow('Đăng bởi', doc.ownerEmail),
              if (doc.description.isNotEmpty)
                _detailRow('Mô tả', doc.description),
              if (doc.fileName.isNotEmpty) _detailRow('File', doc.fileName),
              if (doc.tagNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: doc.tagNames
                      .map((t) => Chip(
                            label: Text('#$t'),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          if (doc.fileUrl.isNotEmpty)
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(doc.fileUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Mở file'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalLinks = _tags.fold<int>(0, (sum, t) => sum + t.documentCount);

    return Scaffold(
      body: SingleChildScrollView(
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
                        'Phân loại & Gắn thẻ Tag',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hệ thống thẻ tag dùng chung cho toàn bộ kho tài liệu.',
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
                  onPressed: _addTag,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm tag'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildError(theme)
            else if (_tags.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                      'Chưa có tag nào. Bấm "Thêm tag" để tạo tag đầu tiên.'),
                ),
              )
            else ...[
              Text(
                '${_tags.length} tag • $totalLinks lượt gắn vào tài liệu',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < _tags.length; i++)
                    _buildTagCard(theme, _tags[i], _palette[i % _palette.length]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Không tải được dữ liệu tag.\nKiểm tra lại cấu hình Supabase (URL/anon key + đã chạy schema.sql chưa).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
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
      ),
    );
  }

  Widget _buildTagCard(ThemeData theme, TagModel tag, Color color) {
    return SizedBox(
      width: 210,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDocumentsWithTag(tag),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSmall),
                      ),
                      child: Icon(Icons.tag, color: color, size: 20),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _renameTag(tag);
                        if (v == 'delete') _deleteTag(tag);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa tag')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '#${tag.name}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${tag.documentCount} tài liệu',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog nhập tên tag — tự quản lý controller nên dispose an toàn.
class _TagFormDialog extends StatefulWidget {
  final String title;
  final String initial;
  const _TagFormDialog({required this.title, this.initial = ''});

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Tên tag',
          hintText: 'vd: flutter, giai-thuat, de-thi',
          prefixIcon: Icon(Icons.tag),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(context, v);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
