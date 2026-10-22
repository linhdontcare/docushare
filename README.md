# DocuShare - Hệ thống Quản lý Tài liệu Đa nền tảng

> **Học phần:** Mini Project TH2  
> **Đội ngũ phát triển:** Nhóm 4 sinh viên  
> **Nền tảng hỗ trợ:** Android & Web  

---

## 📌 1. Giới thiệu Dự án

**DocuShare** là giải pháp quản lý tài liệu học tập, giáo trình, đề thi và sách tham khảo đa nền tảng dành cho sinh viên và giảng viên. Ứng dụng cung cấp khả năng tìm kiếm, định vị tài liệu trong kho lưu trữ vật lý lẫn kỹ thuật số, quản lý mượn trả, chia sẻ theo nhóm học phần và đặc biệt là hệ thống đề xuất tài liệu thông minh (AI Recommendation).

### Công nghệ dự kiến:
- **Frontend / Client:** Flutter (Dart) - Hỗ trợ Android và Web
- **Xác thực & Thông báo:** Firebase Authentication, Firebase Cloud Messaging
- **Cơ sở dữ liệu & Lưu trữ tệp:** Supabase Database (PostgreSQL) và Supabase Storage

---

## 👥 2. Phân công Vai trò & Trách nhiệm (4 Thành viên)

| Thành viên | Vai trò | Phụ trách chính | Module tương ứng |
| :--- | :--- | :--- | :--- |
| **Mã Khánh Linh** | Lead Developer | Khởi tạo Project, Quản lý Git/Repo, Thuật toán Đề xuất, Tích hợp & Kiểm thử tổng thể | `features/recommendation`, `core/`, `shared/` |
| **Dương Quốc Vượng** | Developer | Xác thực người dùng & Phân quyền, Hồ sơ cá nhân | `features/auth` |
| **Vũ Bá Đài** | Developer | Quản lý kho tài liệu, Tải lên tệp & Hệ thống gắn thẻ Tag | `features/documents`, `features/tagging` |
| **Lê Văn Dân** | Developer | Quản lý mượn - trả, Vị trí kho lưu trữ & Chia sẻ | `features/borrowing`, `features/location`, `features/sharing` |

---

## 🏗️ 3. Cấu trúc Thư mục (Feature-First Architecture)

Dự án áp dụng cấu trúc **Feature-First** giúp các thành viên làm việc song song độc lập, hạn chế tối đa xung đột (merge conflicts):

```text
lib/
├── core/                               # Các thành phần cốt lõi của ứng dụng
│   ├── constants/                      # Hằng số màu sắc, chuỗi văn bản, spacing
│   │   ├── app_colors.dart
│   │   ├── app_constants.dart
│   │   └── app_strings.dart
│   ├── theme/                          # Cấu hình Material 3 (Light / Dark mode)
│   │   └── app_theme.dart
│   └── utils/                          # Tiện ích bổ trợ (Responsive Web vs Android)
│       └── responsive.dart
│
├── shared/                             # Thành phần tái sử dụng giữa các feature
│   ├── models/                         # Dữ liệu dùng chung (NavItem, ...)
│   └── widgets/                        # Widget tái sử dụng (AppStatCard, Adaptive Scaffold, ...)
│
├── features/                           # Các module nghiệp vụ chính
│   ├── auth/                           # Xác thực & Phân quyền (Firebase Auth)
│   ├── dashboard/                      # Màn hình Tổng quan số liệu & lối tắt
│   ├── documents/                      # Quản lý tài liệu, tải lên, xem trước (Supabase)
│   ├── tagging/                        # Thẻ tag phân loại, danh mục môn học
│   ├── location/                       # Định vị ngăn kệ, tủ sách, quét QR vị trí
│   ├── borrowing/                      # Quản lý mượn trả, hạn chót, nhắc nhở
│   ├── sharing/                        # Chia sẻ tài liệu, tạo liên kết, mã QR
│   └── recommendation/                 # Hệ thống gợi ý thông minh (Nhóm trưởng)
│
└── main.dart                           # Điểm khởi chạy ứng dụng
```

---

## 🚀 4. Hướng dẫn Cài đặt & Khởi chạy

### Yêu cầu tiên quyết:
- Đã cài đặt **Flutter SDK** (Khuyến nghị bản mới nhất, tối thiểu Dart `^3.13.4`).
- Đã cài đặt **Android Studio** (cho thiết bị Android/Giả lập) hoặc trình duyệt **Google Chrome / Microsoft Edge** (cho nền tảng Web).
- Trình soạn thảo: **VS Code** hoặc **Android Studio** có cài đặt Flutter Extension.

### Các bước khởi chạy:

1. **Clone repository:**
   ```bash
   git clone <URL_REPO_GITHUB>
   cd docushare
   ```

2. **Cài đặt dependencies:**
   ```bash
   flutter pub get
   ```

3. **Kiểm tra thiết bị kết nối:**
   ```bash
   flutter devices
   ```

4. **Chạy ứng dụng:**
   - **Chạy trên Web (Chrome):**
     ```bash
     flutter run -d chrome
     ```
   - **Chạy trên Web (Edge):**
     ```bash
     flutter run -d edge
     ```
   - **Chạy trên Android:**
     ```bash
     flutter run -d android
     ```
     *(Hoặc chọn thiết bị trong thanh trạng thái của VS Code/Android Studio và bấm `F5`)*

---

## 🧪 5. Kiểm tra & Đảm bảo Chất lượng Mã nguồn

Trước khi tạo Pull Request, thành viên **bắt buộc** chạy 2 lệnh sau để đảm bảo không có lỗi linter và test:

```bash
# 1. Phân tích cú pháp và quy chuẩn code (phải đạt 0 errors, 0 warnings)
flutter analyze

# 2. Chạy bộ kiểm thử tự động
flutter test
```

---

## 🌿 6. Quy tắc Làm việc với Git & GitHub

Để tránh xung đột mã nguồn khi 4 người cùng làm việc:

1. **Không commit trực tiếp vào nhánh `main`:**
   Nhánh `main` là nhánh ổn định, chỉ được merge qua Pull Request (PR) sau khi Nhóm trưởng review.

2. **Quy tắc đặt tên nhánh (Branch naming):**
   - Tính năng mới: `feature/<tên-thành-viên>-<tên-module>`  
     *Ví dụ: `feature/nam-auth`, `feature/tuan-documents`*
   - Sửa lỗi: `fix/<tên-lỗi>`

3. **Quy chuẩn thông điệp Commit (Conventional Commits):**
   - `feat: thêm giao diện upload file tài liệu`
   - `fix: sửa lỗi tràn giao diện trên màn hình nhỏ`
   - `docs: cập nhật hướng dẫn kết nối database`
   - `refactor: tối ưu hóa widget danh sách gợi ý`

4. **Bảo mật thông tin:**
   - Tuyệt đối không commit các file cấu hình chứa API key, mật khẩu, file `.env`, `google-services.json` cá nhân lên GitHub công khai. File `.gitignore` đã được cấu hình sẵn để bảo vệ nhóm.

---

## 📅 7. Kế hoạch Các Bước Tiếp Theo

- [x] Khởi tạo khung dự án Flutter đa nền tảng (Android & Web)
- [x] Thiết lập cấu trúc Feature-First & Design System Material 3
- [x] Xây dựng Dashboard mẫu và các màn hình placeholder cho từng module
- [x] Hoàn thiện module Xác thực người dùng, Phân quyền RBAC & Hồ sơ cá nhân (`features/auth` - Dương Quốc Vượng)
- [x] Tích hợp Firebase Authentication, Cloud Firestore (RBAC) & Cloud Messaging (Project: `docushare-th2-3a9b`)
- [ ] Tích hợp Supabase Database & Storage cho tệp tài liệu
- [ ] Hoàn thiện nghiệp vụ từng module và phát triển thuật toán Recommendation
- [ ] Kiểm thử tích hợp (Integration Test) & Đóng gói sản phẩm
