-- ==============================================================================
-- MIGRATION PATCH: 03_fix_users_trigger_email_claim.sql
-- DỰ ÁN: EduVault (LDC Edition)
--
-- MỤC ĐÍCH:
--   Sửa lỗi trích xuất claim 'email' trong Trigger `enforce_user_profile_rules`
--   cho tài khoản đăng nhập Firebase Third-Party Auth.
--
-- NGUYÊN NHÂN CẦN BẢN VÁ:
--   Trong file 02_security_rls_and_triggers_v3.sql, trigger trích xuất email qua:
--     v_jwt_email := auth.jwt() ->> 'email';
--   Tuy nhiên, khi sử dụng Supabase Third-Party Auth (Firebase Auth), các claims
--   được PostgREST lưu trong PostgreSQL session setting `request.jwt.claims`.
--   Nếu hàm auth.jwt() trả về NULL, biến v_jwt_email sẽ bị NULL và kích hoạt
--   ngoại lệ "Bảo mật: Token xác thực Firebase thiếu claim email", làm cho câu
--   lệnh INSERT/UPSERT vào public.users bị hủy (rollback).
--
-- GIẢI PHÁP AN TOÀN:
--   Sử dụng COALESCE kết hợp giữa auth.jwt(), request.jwt.claims và NEW.email
--   để đảm bảo email luôn được ghi nhận chính xác, đồng thời vẫn giữ nguyên:
--   - Bắt buộc phải có Firebase UID hợp lệ (public.firebase_uid() IS NOT NULL).
--   - Khóa bất biến id, firebase_uid, email khi UPDATE (chống giả mạo tài khoản).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.enforce_user_profile_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_jwt_uid TEXT;
  v_jwt_email TEXT;
BEGIN
  -- 1. Trích xuất Firebase UID từ claim 'sub'
  v_jwt_uid := public.firebase_uid();

  -- 2. Trích xuất an toàn claim 'email' bằng COALESCE từ nhiều nguồn claims hợp lệ
  v_jwt_email := COALESCE(
    auth.jwt() ->> 'email',
    (current_setting('request.jwt.claims', true)::jsonb) ->> 'email',
    nullif(trim(NEW.email), '')
  );

  -- Bắt buộc phiên gọi phải có Firebase JWT hợp lệ
  IF v_jwt_uid IS NULL THEN
    RAISE EXCEPTION 'Bảo mật: Yêu cầu đăng nhập xác thực Firebase JWT trước khi thao tác trên bảng users.'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- Bắt buộc phải có email hợp lệ
    IF v_jwt_email IS NULL OR trim(v_jwt_email) = '' THEN
      RAISE EXCEPTION 'Bảo mật: Yêu cầu email hợp lệ để khởi tạo hồ sơ người dùng.'
        USING ERRCODE = '23502';
    END IF;

    -- Tự động gán cứng firebase_uid từ token đã kiểm chứng và chuẩn hóa email
    NEW.firebase_uid := v_jwt_uid;
    NEW.email := lower(trim(v_jwt_email));

  ELSIF TG_OP = 'UPDATE' THEN
    -- Khóa bất biến: cấm sửa firebase_uid hoặc email sang giá trị khác
    IF (NEW.firebase_uid IS DISTINCT FROM OLD.firebase_uid) OR
       (NEW.email IS DISTINCT FROM OLD.email) THEN
      RAISE EXCEPTION 'Bảo mật: Không được phép thay đổi firebase_uid hoặc email của người dùng.'
        USING ERRCODE = '42501';
    END IF;

    -- Tự động giữ nguyên id và created_at gốc để hỗ trợ lệnh UPSERT an toàn
    NEW.id := OLD.id;
    NEW.created_at := OLD.created_at;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Gắn lại Trigger sau khi cập nhật hàm
DROP TRIGGER IF EXISTS trg_enforce_user_profile_rules ON public.users;
CREATE TRIGGER trg_enforce_user_profile_rules
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.enforce_user_profile_rules();
