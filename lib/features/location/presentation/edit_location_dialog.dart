import 'package:flutter/material.dart';

class EditLocationDialog extends StatefulWidget {
  final Map<String, String> location;

  const EditLocationDialog({super.key, required this.location});

  @override
  State<EditLocationDialog> createState() => _EditLocationDialogState();
}

class _EditLocationDialogState extends State<EditLocationDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late TextEditingController _usedController;

  @override
  void initState() {
    super.initState();

    final capacityParts = (widget.location['capacity'] ?? '0/100').split('/');

    _codeController = TextEditingController(
      text: widget.location['code'] ?? '',
    );

    _nameController = TextEditingController(
      text: widget.location['name'] ?? '',
    );

    _usedController = TextEditingController(text: capacityParts[0]);

    _capacityController = TextEditingController(
      text: capacityParts.length > 1 ? capacityParts[1] : '100',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _capacityController.dispose();
    _usedController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final capacity = int.parse(_capacityController.text.trim());
    final used = int.parse(_usedController.text.trim());

    if (used > capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số lượng sử dụng không được vượt sức chứa'),
        ),
      );
      return;
    }

    Navigator.pop(context, <String, String>{
      'code': _codeController.text.trim().toUpperCase(),
      'name': _nameController.text.trim(),
      'capacity': '$used/$capacity',
      'status': used >= capacity * 0.9 ? 'Gần đầy' : 'Còn chỗ',
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa vị trí lưu trữ'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã vị trí',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập mã vị trí'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên vị trí',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên vị trí'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sức chứa tối đa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = int.tryParse(value?.trim() ?? '');
                    return n == null || n <= 0
                        ? 'Nhập số nguyên lớn hơn 0'
                        : null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _usedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng đang lưu trữ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final n = int.tryParse(value?.trim() ?? '');
                    return n == null || n < 0
                        ? 'Nhập số nguyên không âm'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu thay đổi')),
      ],
    );
  }
}
