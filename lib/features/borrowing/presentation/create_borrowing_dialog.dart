import 'package:flutter/material.dart';

import '../data/borrowing_service.dart';
import '../../auth/data/auth_service.dart';

class CreateBorrowingDialog extends StatefulWidget {
  const CreateBorrowingDialog({super.key});

  @override
  State<CreateBorrowingDialog> createState() => _CreateBorrowingDialogState();
}

class _CreateBorrowingDialogState extends State<CreateBorrowingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _documentsFuture;

  String? _selectedDocumentId;
  String? _selectedDocumentTitle;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();

    _documentsFuture = BorrowingService.instance.fetchDocuments();

    final user = AuthService.instance.currentUser;

    if (user != null) {
      _borrowerController.text = user.fullName;
    }
  }

  @override
  void dispose() {
    _borrowerController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _dueDate = selected;
      });
    }
  }

  void _submit() {
    final user = AuthService.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập trước khi mượn tài liệu'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDocumentId == null || _selectedDocumentTitle == null) {
      return;
    }

    Navigator.pop(context, {
      'documentId': _selectedDocumentId,
      'docTitle': _selectedDocumentTitle,
      'borrowerId': user.id,
      'borrower': user.fullName,
      'dueDate':
          '${_dueDate.day.toString().padLeft(2, '0')}/'
          '${_dueDate.month.toString().padLeft(2, '0')}/'
          '${_dueDate.year}',
      'daysLeft': 'Đang mượn',
      'status': 'Đang mượn',
      'statusColor': Colors.blue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo phiếu mượn tài liệu'),

      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chọn tài liệu từ Supabase
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _documentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Đang tải danh sách tài liệu...'),
                          ],
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Text(
                            'Không thể tải danh sách tài liệu',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _documentsFuture = BorrowingService.instance
                                    .fetchDocuments();
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      );
                    }

                    final documents = snapshot.data ?? [];

                    if (documents.isEmpty) {
                      return const Text('Chưa có tài liệu nào trên Supabase.');
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedDocumentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn tài liệu',
                        prefixIcon: Icon(Icons.menu_book),
                        border: OutlineInputBorder(),
                      ),
                      items: documents.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc['id'] as String,
                          child: Text(
                            doc['title'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final document = documents.firstWhere(
                          (doc) => doc['id'] == value,
                        );

                        setState(() {
                          _selectedDocumentId = value;
                          _selectedDocumentTitle = document['title'] as String;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Vui lòng chọn tài liệu';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Nhập người mượn
                TextFormField(
                  controller: _borrowerController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Người mượn',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập người mượn';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Chọn hạn trả
                ListTile(
                  title: const Text('Hạn trả tài liệu'),
                  subtitle: Text(
                    '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _selectDueDate,
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
        FilledButton(onPressed: _submit, child: const Text('Tạo phiếu')),
      ],
    );
  }
}
