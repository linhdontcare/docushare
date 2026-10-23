-- ==============================================================================
-- MIGRATION: 05_document_detailed_location.sql
-- DỰ ÁN: EduVault - Detailed Physical Location & Map Coordinates Extension
--
-- MỤC ĐÍCH:
--   1. Chuẩn hóa và mở rộng thông tin vị trí vật lý chi tiết của tài liệu trong
--      bảng `public.documents`:
--      - location_name: Tên địa điểm / cơ sở (VD: Thư viện Tạ Quang Bửu, Thư viện Trung tâm ĐHQG...)
--      - building: Tòa nhà hoặc thư viện (VD: Nhà Tạ Quang Bửu, Tòa nhà E3, Nhà B1...)
--      - floor: Tầng lưu trữ (VD: Tầng 2, Tầng 3...)
--      - shelf: Phòng hoặc kệ sách (VD: Kệ A3-02, Kệ IT-04, Phòng đọc chuyên khảo...)
--   2. Đảm bảo các cột tọa độ GPS (latitude, longitude) và ghi chú (location_notes)
--      đã sẵn sàng và có chỉ mục hỗ trợ truy vấn không gian.
--   3. Bảo vệ RLS: Giữ nguyên cơ chế bảo mật (chỉ Owner và người có quyền Editor
--      mới được cập nhật vị trí; Viewer chỉ có quyền đọc).
--
-- CÁCH CHẠY:
--   Copy toàn bộ nội dung file này và chạy trong Supabase SQL Editor.
-- ==============================================================================

BEGIN;

-- 1. Bổ sung các trường vị trí vật lý chi tiết vào bảng public.documents
ALTER TABLE public.documents
  ADD COLUMN IF NOT EXISTS location_name TEXT,
  ADD COLUMN IF NOT EXISTS building TEXT,
  ADD COLUMN IF NOT EXISTS floor TEXT,
  ADD COLUMN IF NOT EXISTS shelf TEXT,
  ADD COLUMN IF NOT EXISTS physical_location TEXT,
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_notes TEXT,
  ADD COLUMN IF NOT EXISTS is_available_for_borrow BOOLEAN DEFAULT true NOT NULL;

-- 2. Đặt chú thích (Comments) giải thích rõ chức năng từng cột
COMMENT ON COLUMN public.documents.location_name IS 'Tên địa điểm lưu trữ chính (VD: Thư viện Tạ Quang Bửu, Lab AI...)';
COMMENT ON COLUMN public.documents.building IS 'Tên tòa nhà hoặc khu thư viện (VD: Nhà TQB, Tòa nhà E3, Nhà C2...)';
COMMENT ON COLUMN public.documents.floor IS 'Tầng chứa tài liệu (VD: Tầng 2, Tầng 3, Tầng 5...)';
COMMENT ON COLUMN public.documents.shelf IS 'Phòng đọc, tủ hoặc kệ sách cụ thể (VD: Kệ IT-04, Kệ A2, Tủ khóa 12...)';
COMMENT ON COLUMN public.documents.physical_location IS 'Chuỗi địa chỉ tổng hợp hoặc mô tả vị trí tự do để tương thích ngược';
COMMENT ON COLUMN public.documents.latitude IS 'Vĩ độ GPS chuẩn WGS84 (-90.0 đến 90.0)';
COMMENT ON COLUMN public.documents.longitude IS 'Kinh độ GPS chuẩn WGS84 (-180.0 đến 180.0)';
COMMENT ON COLUMN public.documents.location_notes IS 'Ghi chú hướng dẫn tìm kiếm và quy định mượn tài liệu tại chỗ';

-- 3. Tạo index phục vụ tìm kiếm và lọc theo địa điểm / tòa nhà
CREATE INDEX IF NOT EXISTS idx_documents_location_name ON public.documents(location_name);
CREATE INDEX IF NOT EXISTS idx_documents_building ON public.documents(building);
CREATE INDEX IF NOT EXISTS idx_documents_coordinates ON public.documents(latitude, longitude) 
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

COMMIT;
