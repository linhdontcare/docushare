import 'package:flutter/foundation.dart';

/// Tín hiệu đồng bộ dữ liệu dùng chung giữa các module (Documents, Tagging...).
///
/// Vấn đề: các trang nằm trong IndexedStack nên không bị hủy khi chuyển tab,
/// dữ liệu tải 1 lần ở initState sẽ cũ nếu module khác vừa thay đổi.
/// Cách giải quyết: mỗi khi service thêm/sửa/xóa tài liệu hoặc tag, gọi
/// [notifyChanged] để mọi màn hình đang lắng nghe tự tải lại dữ liệu mới.
class LibrarySync extends ChangeNotifier {
  LibrarySync._();
  static final LibrarySync instance = LibrarySync._();

  void notifyChanged() => notifyListeners();
}
