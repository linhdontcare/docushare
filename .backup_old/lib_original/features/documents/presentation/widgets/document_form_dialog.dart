import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/document_service.dart';
import '../../domain/models/document_model.dart';

/// Dialog thêm / sửa tài liệu.
/// Tự quản lý toàn bộ TextEditingController nên dispose an toàn
/// (không dispose ngay sau Navigator.pop như lỗi cũ).
class DocumentFormDialog extends StatefulWidget {
  final String ownerId;
  final String ownerEmail;
  final DocumentModel? existing;
  final List<String> tagSuggestions;

  const DocumentFormDialog({
    super.key,
    required this.ownerId,
    required this.ownerEmail,
    this.existing,
    this.tagSuggestions = const [],
  });

  @override
  State<DocumentFormDialog> createState() => _DocumentFormDialogState();
}

class _DocumentFormDialogState extends State<DocumentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _service = DocumentService.instance;

  late final TextEditingController _title;
  late final TextEditingController _author;
  late final TextEditingController _description;
  late final TextEditingController _tagInput;
  String _category = 'Giáo trình';
  List<String> _tags = [];

  PlatformFile? _pickedFile; // file mới chọn (null = giữ file cũ)
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _author = TextEditingController(text: e?.author ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _tagInput = TextEditingController();
    _category = e?.category ?? 'Giáo trình';
    _tags = e?.tagNames ?? [];
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _description.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final name = raw.trim().replaceAll('#', '');
    if (name.isEmpty || _tags.contains(name)) return;
    setState(() {
      _tags.add(name);
      _tagInput.clear();
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      var fileUrl = widget.existing?.fileUrl ?? '';
      var fileName = widget.existing?.fileName ?? '';

      // Có file mới -> upload lên Supabase Storage trước
      if (_pickedFile != null && _pickedFile!.bytes != null) {
        fileUrl = await _service.uploadFile(_pickedFile!.bytes!, _pickedFile!.name);
        fileName = _pickedFile!.name;
      }

      if (widget.existing == null) {
        await _service.createDocument(
          ownerId: widget.ownerId,
          ownerEmail: widget.ownerEmail,
          title: _title.text.trim(),
          author: _author.text.trim(),
          category: _category,
          description: _description.text.trim(),
          fileUrl: fileUrl,
          fileName: fileName,
          tagNames: _tags,
        );
      } else {
        await _service.updateDocument(
          documentId: widget.existing!.id,
          title: _title.text.trim(),
          author: _author.text.trim(),
          category: _category,
          description: _description.text.trim(),
          fileUrl: fileUrl,
          fileName: fileName,
          tagNames: _tags,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final currentFileName = _pickedFile?.name ?? widget.existing?.fileName ?? '';

    return AlertDialog(
      title: Text(isEdit ? 'Sửa tài liệu' : 'Tải lên tài liệu'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề *',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _author,
                  decoration: const InputDecoration(
                    labelText: 'Tác giả / Nguồn',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Danh mục',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: DocumentModel.categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text('Thẻ tag',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _tags
                      .map((t) => Chip(
                            label: Text('#$t'),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () =>
                                setState(() => _tags.remove(t)),
                          ))
                      .toList(),
                ),
                TextField(
                  controller: _tagInput,
                  decoration: const InputDecoration(
                    hintText: 'Nhập tag rồi bấm Enter',
                    prefixIcon: Icon(Icons.tag, size: 20),
                  ),
                  onSubmitted: _addTag,
                ),
                if (widget.tagSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: widget.tagSuggestions
                        .where((s) => !_tags.contains(s))
                        .take(8)
                        .map((s) => ActionChip(
                              label: Text('#$s'),
                              onPressed: () => _addTag(s),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(currentFileName.isEmpty
                      ? 'Chọn file đính kèm'
                      : currentFileName),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Lưu thay đổi' : 'Tải lên'),
        ),
      ],
    );
  }
}
