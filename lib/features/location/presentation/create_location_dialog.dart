import 'package:flutter/material.dart';

class CreateLocationDialog extends StatefulWidget {
  const CreateLocationDialog({super.key});

  @override
  State<CreateLocationDialog> createState() => _CreateLocationDialogState();
}

class _CreateLocationDialogState extends State<CreateLocationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();
  final _usedController = TextEditingController(text: '0');

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _capacityController.dispose();
    _usedController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final capacity = int.parse(_capacityController.text.trim());
    final used = int.parse(_usedController.text.trim());

    if (used > capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số lượng đã sử dụng không được vượt sức chứa'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'code': _codeController.text.trim().toUpperCase(),
      'name': _nameController.text.trim(),
      'capacity': '$used/$capacity',
      'status': used >= capacity * 0.9 ? 'Gần đầy' : 'Còn chỗ',
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm vị trí lưu trữ'),
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
                    hintText: 'VD: KHO-D1',
                    prefixIcon: Icon(Icons.qr_code),
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
                    hintText: 'VD: Phòng Đọc 2 - Tủ D',
                    prefixIcon: Icon(Icons.place),
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
                    hintText: 'VD: 100',
                    prefixIcon: Icon(Icons.inventory_2),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final number = int.tryParse(value?.trim() ?? '');
                    if (number == null || number <= 0) {
                      return 'Nhập số nguyên lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _usedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng đang lưu trữ',
                    prefixIcon: Icon(Icons.folder),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final number = int.tryParse(value?.trim() ?? '');
                    if (number == null || number < 0) {
                      return 'Nhập số nguyên không âm';
                    }
                    return null;
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
        FilledButton(onPressed: _submit, child: const Text('Thêm vị trí')),
      ],
    );
  }
}
