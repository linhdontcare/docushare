-- ==============================================================================
-- MIGRATION: 01_init_schema_and_rls.sql (REVISED - V3)
-- DỰ ÁN: EduVault (LDC Edition)
--
-- CÁC NÂNG CẤP VÀ SỬA ĐỔI QUAN TRỌNG TRONG PHIÊN BẢN V3:
--   1. [FIX LỖI 42P01]: Chuẩn hóa thứ tự phụ thuộc chính xác 100%:
--      BƯỚC 1: Extensions
--      BƯỚC 2: Định nghĩa 3 Bảng (users -> documents -> permissions)
--      BƯỚC 3: Indexes
--      BƯỚC 4: Các hàm xác thực & kiểm tra quyền (khi các bảng đã tồn tại)
--      BƯỚC 5: Triggers & Hàm Trigger
--      BƯỚC 6: Bật RLS & Tạo Policies
--      BƯỚC 7: Phân quyền GRANT/REVOKE (Khóa hoàn toàn anon)
--   2. [CHỐNG SPOOFING USER_ID]: Các hàm kiểm tra quyền không nhận p_user_id từ
--      bên ngoài mà tự động trích xuất public.current_user_id() nội bộ:
--      - public.is_current_user_owner(p_doc_id UUID)
--      - public.has_current_user_permission(p_doc_id UUID, p_required_type TEXT)
--      Người dùng không thể truyền user_id của nạn nhân để vượt mặt RLS.
--   3. [CHỐNG RLS RECURSION]: Các hàm kiểm tra quyền chạy SECURITY DEFINER với
--      search_path cố định, truy cập bảng mục tiêu mà không kích hoạt RLS chéo.
--   4. [SIẾT CHẶT QUYỀN ANON]: Thu hồi toàn bộ quyền EXECUTE và bảng khỏi role 'anon'.
--      Chỉ cấp quyền cho role 'authenticated'.
--   5. [SIẾT CHẶT QUYỀN EDITOR]: Trigger enforce_document_update_rules ngăn Editor
--      can thiệp các trường nhạy cảm (owner_id, storage_path, file_name, file_type,
--      file_size, created_at).
--   6. [IDEMPOTENT & NON-DESTRUCTIVE]: Dùng IF NOT EXISTS, CREATE OR REPLACE,
--      DROP POLICY IF EXISTS. Tuyệt đối không xóa bảng hay làm mất dữ liệu cũ.
-- ==============================================================================

-- ==============================================================================
-- BƯỚC 1: KHỞI TẠO EXTENSIONS
-- ==============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- BƯỚC 2: TẠO CÁC BẢNG (THEO ĐÚNG THỨ TỰ RÀNG BUỘC KHÓA NGOẠI)
-- ==============================================================================

-- 2.1. BẢNG USERS (Đồng bộ từ Firebase Authentication)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.users IS 'Thông tin người dùng đồng bộ từ Firebase Auth, định danh khóa chính UUID.';
COMMENT ON COLUMN public.users.firebase_uid IS 'Firebase UID duy nhất được kiểm chứng từ JWT token Google.';

-- 2.2. BẢNG DOCUMENTS (Metadata tài liệu học tập)
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  subject TEXT,
  category_id TEXT DEFAULT 'all' NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size BIGINT NOT NULL CHECK (file_size >= 0),
  storage_path TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.documents IS 'Metadata tài liệu học tập. File nhị phân lưu tại Firebase Storage theo storage_path.';

-- 2.3. BẢNG PERMISSIONS (Phân quyền cộng tác chia sẻ)
CREATE TABLE IF NOT EXISTS public.permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  permission_type TEXT NOT NULL CHECK (permission_type IN ('viewer', 'editor')),
  granted_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  -- Ràng buộc chống tạo bản ghi quyền trùng lặp cho cùng một người dùng trên một tài liệu
  CONSTRAINT unique_document_user_permission UNIQUE (document_id, user_id)
);

COMMENT ON TABLE public.permissions IS 'Bảng phân quyền chia sẻ: viewer (chỉ xem/tải), editor (xem/sửa metadata).';

-- ==============================================================================
-- BƯỚC 3: TẠO INDEXES TỐI ƯU TRUY VẤN
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON public.users(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

CREATE INDEX IF NOT EXISTS idx_documents_owner_id ON public.documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON public.documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_category_id ON public.documents(category_id);
CREATE INDEX IF NOT EXISTS idx_documents_title ON public.documents(title);
CREATE INDEX IF NOT EXISTS idx_documents_subject ON public.documents(subject);

CREATE INDEX IF NOT EXISTS idx_permissions_doc_user ON public.permissions(document_id, user_id);
CREATE INDEX IF NOT EXISTS idx_permissions_user_id ON public.permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_permissions_doc_id ON public.permissions(document_id);

-- ==============================================================================
-- BƯỚC 4: TẠO CÁC HÀM XÁC THỰC VÀ KIỂM TRA QUYỀN (KHI CÁC BẢNG ĐÃ TỒN TẠI)
-- ==============================================================================

-- 4.1. Trích xuất Firebase UID từ JWT token đã được Supabase Gateway xác minh chữ ký
CREATE OR REPLACE FUNCTION public.firebase_uid()
RETURNS TEXT AS $$
  SELECT COALESCE(
    auth.jwt() ->> 'sub',
    (current_setting('request.jwt.claims', true)::jsonb) ->> 'sub'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

COMMENT ON FUNCTION public.firebase_uid() IS 'Trích xuất an toàn claim sub (Firebase UID) từ JWT được Supabase xác minh.';

-- 4.2. Lấy UUID nội bộ (public.users.id) của người dùng hiện tại
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS UUID AS $$
  SELECT id FROM public.users
  WHERE firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

COMMENT ON FUNCTION public.current_user_id() IS 'Tra cứu UUID trong bảng users tương ứng với Firebase UID đã xác thực.';

-- 4.3. Kiểm tra xem người gọi hiện tại có phải là Owner của tài liệu hay không
--      (Không nhận p_user_id từ bên ngoài để chống giả mạo danh tính, chống RLS recursion)
CREATE OR REPLACE FUNCTION public.is_current_user_owner(p_doc_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := public.current_user_id();
  IF v_caller_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.documents
    WHERE id = p_doc_id AND owner_id = v_caller_id
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 4.4. Kiểm tra xem người gọi hiện tại có quyền hợp lệ trên tài liệu hay không
--      (Tự trích xuất current_user_id(), bypasses permissions RLS chống recursion)
CREATE OR REPLACE FUNCTION public.has_current_user_permission(
  p_doc_id UUID,
  p_required_type TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := public.current_user_id();
  IF v_caller_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.permissions
    WHERE document_id = p_doc_id
      AND user_id = v_caller_id
      AND (p_required_type IS NULL OR permission_type = p_required_type)
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 4.5. Hàm RPC kiểm tra quyền tải file tại phía Server
CREATE OR REPLACE FUNCTION public.check_file_access_permission(
  p_document_id UUID
)
RETURNS TABLE (
  has_access BOOLEAN,
  role TEXT,
  storage_path TEXT,
  file_name TEXT
) AS $$
DECLARE
  v_caller_id UUID;
  v_doc RECORD;
  v_perm_type TEXT;
BEGIN
  v_caller_id := public.current_user_id();
  IF v_caller_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  SELECT d.id, d.owner_id, d.storage_path, d.file_name
  INTO v_doc
  FROM public.documents d
  WHERE d.id = p_document_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  -- 1. Nếu caller là Owner
  IF v_doc.owner_id = v_caller_id THEN
    RETURN QUERY SELECT true, 'owner'::TEXT, v_doc.storage_path, v_doc.file_name;
    RETURN;
  END IF;

  -- 2. Nếu caller có quyền trong permissions
  SELECT p.permission_type INTO v_perm_type
  FROM public.permissions p
  WHERE p.document_id = p_document_id
    AND p.user_id = v_caller_id;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_perm_type, v_doc.storage_path, v_doc.file_name;
    RETURN;
  END IF;

  -- 3. Không có quyền
  RETURN QUERY SELECT false, NULL::TEXT, NULL::TEXT, NULL::TEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- ==============================================================================
-- BƯỚC 5: TẠO HÀM TRIGGER VÀ GẮN TRIGGER
-- ==============================================================================

-- 5.1. Trigger cập nhật trường updated_at tự động
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS set_users_updated_at ON public.users;
CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_documents_updated_at ON public.documents;
CREATE TRIGGER set_documents_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_permissions_updated_at ON public.permissions;
CREATE TRIGGER set_permissions_updated_at
  BEFORE UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 5.2. Trigger kiểm soát chặt chẽ quyền UPDATE tài liệu:
--      - Cấm tuyệt đối thay đổi owner_id.
--      - Editor chỉ được sửa thông tin mô tả/tiêu đề/môn học.
--      - Editor KHÔNG ĐƯỢC sửa storage_path, file_name, file_type, file_size, created_at.
CREATE OR REPLACE FUNCTION public.enforce_document_update_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_id UUID;
  v_is_owner BOOLEAN;
BEGIN
  v_caller_id := public.current_user_id();

  -- 1. Chống chuyển nhượng owner_id trái phép
  IF NEW.owner_id <> OLD.owner_id THEN
    RAISE EXCEPTION 'Bảo mật: Không được phép thay đổi owner_id của tài liệu.';
  END IF;

  -- 2. Kiểm tra vai trò của người gọi
  v_is_owner := (OLD.owner_id = v_caller_id);

  IF NOT v_is_owner THEN
    -- Trường hợp Editor thực hiện sửa: Khóa toàn bộ các trường nhạy cảm về file
    IF NEW.storage_path <> OLD.storage_path THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép thay đổi storage_path của tài liệu.';
    END IF;
    IF NEW.file_name <> OLD.file_name THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép sửa tên file vật lý (file_name).';
    END IF;
    IF NEW.file_type <> OLD.file_type THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép sửa định dạng file (file_type).';
    END IF;
    IF NEW.file_size <> OLD.file_size THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép sửa dung lượng file (file_size).';
    END IF;
    IF NEW.created_at <> OLD.created_at THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép can thiệp thời gian tạo ban đầu (created_at).';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_document_update_rules ON public.documents;
CREATE TRIGGER trg_enforce_document_update_rules
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.enforce_document_update_rules();

-- 5.3. Trigger kiểm tra tính hợp lệ khi cấp quyền chia sẻ:
--      - Cấm cấp quyền cho chính Owner.
--      - Cấm người dùng tự cấp quyền cho chính mình.
--      - Chỉ Owner của tài liệu mới có quyền gán quyền.
CREATE OR REPLACE FUNCTION public.validate_permission_assignment()
RETURNS TRIGGER AS $$
DECLARE
  v_owner_id UUID;
  v_caller_id UUID;
BEGIN
  SELECT owner_id INTO v_owner_id FROM public.documents WHERE id = NEW.document_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tài liệu không tồn tại.';
  END IF;

  -- 1. Owner đã có toàn quyền, cấm tạo bản ghi trong permissions
  IF NEW.user_id = v_owner_id THEN
    RAISE EXCEPTION 'Owner đã có toàn quyền truy cập tài liệu, không thể cấp quyền trong permissions.';
  END IF;

  v_caller_id := public.current_user_id();

  -- 2. Cấm tự cấp quyền cho chính mình
  IF NEW.user_id = v_caller_id THEN
    RAISE EXCEPTION 'Bảo mật: Người dùng không được phép tự cấp quyền cho chính mình.';
  END IF;

  -- 3. Chỉ Owner của tài liệu mới có quyền gán hoặc sửa quyền
  IF v_caller_id <> v_owner_id THEN
    RAISE EXCEPTION 'Bảo mật: Chỉ Owner của tài liệu mới có quyền chia sẻ hoặc thay đổi quyền.';
  END IF;

  NEW.granted_by := v_caller_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_validate_permission_assignment ON public.permissions;
CREATE TRIGGER trg_validate_permission_assignment
  BEFORE INSERT OR UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.validate_permission_assignment();

-- ==============================================================================
-- BƯỚC 6: BẬT RLS VÀ TẠO POLICIES (CHỐNG RECURSION & CHỐNG GIẢ MẠO)
-- ==============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 6.1. RLS POLICIES CHO BẢNG USERS
-- ------------------------------------------------------------------------------

DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
CREATE POLICY "users_select_authenticated"
  ON public.users
  FOR SELECT
  USING (
    public.firebase_uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "users_insert_self" ON public.users;
CREATE POLICY "users_insert_self"
  ON public.users
  FOR INSERT
  WITH CHECK (
    firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "users_update_self" ON public.users;
CREATE POLICY "users_update_self"
  ON public.users
  FOR UPDATE
  USING (
    firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  )
  WITH CHECK (
    firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "users_delete_deny" ON public.users;
CREATE POLICY "users_delete_deny"
  ON public.users
  FOR DELETE
  USING (false);

-- ------------------------------------------------------------------------------
-- 6.2. RLS POLICIES CHO BẢNG DOCUMENTS (SỬ DỤNG HÀM HELPER CHỐNG RECURSION)
-- ------------------------------------------------------------------------------

-- SELECT: Xem nếu là Owner hoặc có quyền (Viewer / Editor)
DROP POLICY IF EXISTS "documents_select_authorized" ON public.documents;
CREATE POLICY "documents_select_authorized"
  ON public.documents
  FOR SELECT
  USING (
    owner_id = public.current_user_id()
    OR
    public.has_current_user_permission(id)
  );

-- INSERT: Chỉ tạo tài liệu với chính mình làm Owner
DROP POLICY IF EXISTS "documents_insert_owner" ON public.documents;
CREATE POLICY "documents_insert_owner"
  ON public.documents
  FOR INSERT
  WITH CHECK (
    owner_id = public.current_user_id()
  );

-- UPDATE: Owner được sửa toàn bộ, Editor sửa metadata (được kiểm soát bởi Trigger)
DROP POLICY IF EXISTS "documents_update_owner_and_editor" ON public.documents;
CREATE POLICY "documents_update_owner_and_editor"
  ON public.documents
  FOR UPDATE
  USING (
    owner_id = public.current_user_id()
    OR
    public.has_current_user_permission(id, 'editor')
  )
  WITH CHECK (
    owner_id = public.current_user_id()
    OR
    public.has_current_user_permission(id, 'editor')
  );

-- DELETE: CHỈ DUY NHẤT Owner mới có quyền xóa tài liệu
DROP POLICY IF EXISTS "documents_delete_only_owner" ON public.documents;
CREATE POLICY "documents_delete_only_owner"
  ON public.documents
  FOR DELETE
  USING (
    owner_id = public.current_user_id()
  );

-- ------------------------------------------------------------------------------
-- 6.3. RLS POLICIES CHO BẢNG PERMISSIONS (SỬ DỤNG HÀM HELPER CHỐNG RECURSION)
-- ------------------------------------------------------------------------------

-- SELECT: Người nhận xem quyền của mình, Owner xem toàn bộ danh sách chia sẻ
DROP POLICY IF EXISTS "permissions_select_owner_and_recipient" ON public.permissions;
CREATE POLICY "permissions_select_owner_and_recipient"
  ON public.permissions
  FOR SELECT
  USING (
    user_id = public.current_user_id()
    OR
    public.is_current_user_owner(document_id)
  );

-- INSERT: CHỈ Owner của tài liệu mới được chia sẻ cho người khác
DROP POLICY IF EXISTS "permissions_insert_only_owner" ON public.permissions;
CREATE POLICY "permissions_insert_only_owner"
  ON public.permissions
  FOR INSERT
  WITH CHECK (
    public.is_current_user_owner(document_id)
    AND user_id <> public.current_user_id()
  );

-- UPDATE: CHỈ Owner của tài liệu mới được đổi vai trò (Viewer <-> Editor)
DROP POLICY IF EXISTS "permissions_update_only_owner" ON public.permissions;
CREATE POLICY "permissions_update_only_owner"
  ON public.permissions
  FOR UPDATE
  USING (
    public.is_current_user_owner(document_id)
  )
  WITH CHECK (
    public.is_current_user_owner(document_id)
    AND user_id <> public.current_user_id()
  );

-- DELETE (Thu hồi quyền):
--   - Owner thu hồi quyền của bất kỳ ai trên tài liệu của mình.
--   - Người được chia sẻ có thể tự rời khỏi tài liệu (xóa quyền của chính mình).
DROP POLICY IF EXISTS "permissions_delete_owner_or_self" ON public.permissions;
CREATE POLICY "permissions_delete_owner_or_self"
  ON public.permissions
  FOR DELETE
  USING (
    user_id = public.current_user_id()
    OR
    public.is_current_user_owner(document_id)
  );

-- ==============================================================================
-- BƯỚC 7: THIẾT LẬP QUYỀN TRUY CẬP (GRANT/REVOKE CHẶT CHẼ)
-- ==============================================================================

-- 7.1. Thu hồi toàn bộ quyền từ role 'anon' và 'public'
REVOKE ALL ON TABLE public.users FROM anon, public;
REVOKE ALL ON TABLE public.documents FROM anon, public;
REVOKE ALL ON TABLE public.permissions FROM anon, public;

REVOKE ALL ON FUNCTION public.firebase_uid() FROM anon, public;
REVOKE ALL ON FUNCTION public.current_user_id() FROM anon, public;
REVOKE ALL ON FUNCTION public.is_current_user_owner(UUID) FROM anon, public;
REVOKE ALL ON FUNCTION public.has_current_user_permission(UUID, TEXT) FROM anon, public;
REVOKE ALL ON FUNCTION public.check_file_access_permission(UUID) FROM anon, public;

-- 7.2. Cấp quyền cần thiết cho role 'authenticated' (Người dùng đã đăng nhập Firebase)
GRANT SELECT, INSERT, UPDATE ON TABLE public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.permissions TO authenticated;

GRANT EXECUTE ON FUNCTION public.firebase_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_current_user_permission(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_file_access_permission(UUID) TO authenticated;
-- ==============================================================================
-- MIGRATION: 02_advanced_features_schema.sql
-- DỰ ÁN: EduVault - Advanced Features Extension
-- 
-- 1. Quản lý Tags và Document_Tags
-- 2. Quản lý Vị trí vật lý của tài liệu (Physical Locations & Coordinates)
-- 3. Quản lý Luồng Mượn / Trả tài liệu (Borrow Requests Workflow)
-- 4. Quản lý Sở thích người dùng (User Preferences cho Recommendation Engine)
-- 5. Bật Row Level Security (RLS) & Triggers bảo vệ toàn vẹn
-- ==============================================================================

-- ==============================================================================
-- BƯỚC 1: BẢNG TAGS & DOCUMENT_TAGS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  color_hex TEXT DEFAULT '#2563EB',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.tags IS 'Danh mục các nhãn/tag chuẩn trong hệ thống EduVault.';

CREATE TABLE IF NOT EXISTS public.document_tags (
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (document_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_document_tags_doc ON public.document_tags(document_id);
CREATE INDEX IF NOT EXISTS idx_document_tags_tag ON public.document_tags(tag_id);

-- Cập nhật bảng public.documents thêm các trường vị trí vật lý và mượn trả
ALTER TABLE public.documents 
  ADD COLUMN IF NOT EXISTS physical_location TEXT,
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_notes TEXT,
  ADD COLUMN IF NOT EXISTS is_available_for_borrow BOOLEAN DEFAULT true NOT NULL,
  ADD COLUMN IF NOT EXISTS tags_cache TEXT[] DEFAULT '{}'::TEXT[];

-- ==============================================================================
-- BƯỚC 2: BẢNG BORROW_REQUESTS (YÊU CẦU MƯỢN TÀI LIỆU)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.borrow_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'returned')),
  request_date TIMESTAMPTZ DEFAULT now() NOT NULL,
  due_date TIMESTAMPTZ NOT NULL,
  return_date TIMESTAMPTZ,
  notes TEXT,
  owner_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.borrow_requests IS 'Quản lý quy trình mượn - trả tài liệu vật lý và tài liệu số giữa người dùng.';

CREATE INDEX IF NOT EXISTS idx_borrow_requests_doc ON public.borrow_requests(document_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_requester ON public.borrow_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_owner ON public.borrow_requests(owner_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_status ON public.borrow_requests(status);

-- ==============================================================================
-- BƯỚC 3: BẢNG USER_PREFERENCES (LƯU SỞ THÍCH CHO THUẬT TOÁN RECOMMENDATION)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.user_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  preferred_tags TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
  preferred_subjects TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
  preferred_categories TEXT[] DEFAULT '{}'::TEXT[] NOT NULL,
  view_history_doc_ids UUID[] DEFAULT '{}'::UUID[] NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.user_preferences IS 'Lưu trữ thông tin sở thích, lịch sử tương tác để phục vụ Recommendation Engine.';

-- ==============================================================================
-- BƯỚC 4: BẬT RLS (ROW LEVEL SECURITY)
-- ==============================================================================

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.borrow_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- 4.1. POLICIES CHO TAGS
DROP POLICY IF EXISTS "Authenticated users can read tags" ON public.tags;
CREATE POLICY "Authenticated users can read tags" 
  ON public.tags FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert tags" ON public.tags;
CREATE POLICY "Authenticated users can insert tags" 
  ON public.tags FOR INSERT TO authenticated WITH CHECK (true);

-- 4.2. POLICIES CHO DOCUMENT_TAGS
DROP POLICY IF EXISTS "Authenticated users can read document tags" ON public.document_tags;
CREATE POLICY "Authenticated users can read document tags" 
  ON public.document_tags FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Owners can manage document tags" ON public.document_tags;
CREATE POLICY "Owners can manage document tags" 
  ON public.document_tags FOR ALL TO authenticated 
  USING (EXISTS (
    SELECT 1 FROM public.documents d 
    WHERE d.id = document_id AND d.owner_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub')
  ));

-- 4.3. POLICIES CHO BORROW_REQUESTS
DROP POLICY IF EXISTS "Users can view borrow requests they sent or received" ON public.borrow_requests;
CREATE POLICY "Users can view borrow requests they sent or received" 
  ON public.borrow_requests FOR SELECT TO authenticated 
  USING (
    requester_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub')
    OR owner_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub')
  );

DROP POLICY IF EXISTS "Requesters can insert borrow request" ON public.borrow_requests;
CREATE POLICY "Requesters can insert borrow request" 
  ON public.borrow_requests FOR INSERT TO authenticated 
  WITH CHECK (
    requester_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub')
    AND requester_id <> owner_id
  );

DROP POLICY IF EXISTS "Owners and requesters can update borrow request status" ON public.borrow_requests;
CREATE POLICY "Owners and requesters can update borrow request status" 
  ON public.borrow_requests FOR UPDATE TO authenticated 
  USING (
    owner_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub')
    OR requester_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub')
  );

-- 4.4. POLICIES CHO USER_PREFERENCES
DROP POLICY IF EXISTS "Users can manage their own preferences" ON public.user_preferences;
CREATE POLICY "Users can manage their own preferences" 
  ON public.user_preferences FOR ALL TO authenticated 
  USING (user_id = (SELECT id FROM public.users WHERE firebase_uid = auth.jwt()->>'sub'));

-- ==============================================================================
-- BƯỚC 5: CẤP QUYỀN (GRANTS)
-- ==============================================================================

GRANT SELECT, INSERT ON public.tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.borrow_requests TO authenticated;
GRANT ALL ON public.user_preferences TO authenticated;
-- EduVault: security migration for EXISTING public.users, public.documents, public.permissions.
-- Run as the Supabase SQL Editor database owner (postgres). No tables/data are dropped.
-- Assumes Firebase Third-Party Auth is configured and requests reach PostgREST as authenticated.
BEGIN;

-- Private helpers. Definer functions must be owned by a trusted role that bypasses RLS.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE OR REPLACE FUNCTION private.firebase_uid()
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT CASE WHEN (SELECT auth.role()) = 'authenticated'
              THEN NULLIF((SELECT auth.jwt()) ->> 'sub', '')
              ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION private.current_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT u.id FROM public.users AS u
  WHERE u.firebase_uid = private.firebase_uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION private.is_owner(p_document_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.documents AS d
    WHERE d.id = p_document_id AND d.owner_id = private.current_user_id()
  );
$$;

CREATE OR REPLACE FUNCTION private.has_permission(p_document_id uuid, p_type text DEFAULT NULL)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.permissions AS p
    WHERE p.document_id = p_document_id
      AND p.user_id = private.current_user_id()
      AND (p_type IS NULL OR p.permission_type = p_type)
  );
$$;

-- ONE BEFORE UPDATE trigger per table: validate client changes, then stamp updated_at.
-- Avoid trigger ordering conflicts with independent timestamp triggers.
CREATE OR REPLACE FUNCTION private.guard_users()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid text; v_email text;
BEGIN
  v_uid := private.firebase_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authenticated Firebase identity required'; END IF;
  IF TG_OP = 'INSERT' THEN
    v_email := NULLIF(btrim((auth.jwt() ->> 'email')), '');
    IF v_email IS NULL THEN RAISE EXCEPTION 'Firebase token must contain email'; END IF;
    IF NEW.firebase_uid IS DISTINCT FROM v_uid THEN
      RAISE EXCEPTION 'firebase_uid does not match token';
    END IF;
    IF lower(btrim(NEW.email)) IS DISTINCT FROM lower(v_email) THEN
      RAISE EXCEPTION 'email does not match token';
    END IF;
    NEW.email := lower(v_email);
    RETURN NEW;
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.firebase_uid IS DISTINCT FROM OLD.firebase_uid
     OR NEW.email IS DISTINCT FROM OLD.email
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.updated_at IS DISTINCT FROM OLD.updated_at THEN
    RAISE EXCEPTION 'User identity and timestamps cannot be changed';
  END IF;
  -- Only profile display fields are client-editable.
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_documents()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'User profile not found'; END IF;
  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.updated_at IS DISTINCT FROM OLD.updated_at THEN
    RAISE EXCEPTION 'Document identity and timestamps cannot be changed';
  END IF;
  IF OLD.owner_id IS DISTINCT FROM v_user THEN
    IF NOT private.has_permission(OLD.id, 'editor') THEN
      RAISE EXCEPTION 'Editor permission required';
    END IF;
    -- Compare all columns except the 4 editable metadata fields and server timestamp.
    IF (to_jsonb(NEW) - ARRAY['title','description','subject','category_id','updated_at'])
       IS DISTINCT FROM
       (to_jsonb(OLD) - ARRAY['title','description','subject','category_id','updated_at']) THEN
      RAISE EXCEPTION 'Editor may change only title, description, subject, category_id';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_permissions()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid; v_owner uuid;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'User profile not found'; END IF;
  SELECT d.owner_id INTO v_owner FROM public.documents AS d WHERE d.id = NEW.document_id;
  IF v_owner IS NULL OR v_owner IS DISTINCT FROM v_user THEN
    RAISE EXCEPTION 'Only the document owner may assign permissions';
  END IF;
  IF NEW.user_id = v_owner THEN RAISE EXCEPTION 'Owner cannot be a permission recipient'; END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.granted_by := v_user;
    RETURN NEW;
  END IF;
  IF (to_jsonb(NEW) - ARRAY['permission_type','updated_at'])
     IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['permission_type','updated_at']) THEN
    RAISE EXCEPTION 'Only permission_type may be changed';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Remove previous variants if present, then attach the consolidated guards.
DROP TRIGGER IF EXISTS set_users_updated_at ON public.users;
DROP TRIGGER IF EXISTS set_documents_updated_at ON public.documents;
DROP TRIGGER IF EXISTS set_permissions_updated_at ON public.permissions;
DROP TRIGGER IF EXISTS trg_enforce_user_profile_rules ON public.users;
DROP TRIGGER IF EXISTS trg_enforce_document_update_rules ON public.documents;
DROP TRIGGER IF EXISTS trg_validate_permission_assignment ON public.permissions;
DROP TRIGGER IF EXISTS eduvault_guard_users ON public.users;
DROP TRIGGER IF EXISTS eduvault_guard_documents ON public.documents;
DROP TRIGGER IF EXISTS eduvault_guard_permissions ON public.permissions;
CREATE TRIGGER eduvault_guard_users BEFORE INSERT OR UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION private.guard_users();
CREATE TRIGGER eduvault_guard_documents BEFORE UPDATE ON public.documents
FOR EACH ROW EXECUTE FUNCTION private.guard_documents();
CREATE TRIGGER eduvault_guard_permissions BEFORE INSERT OR UPDATE ON public.permissions
FOR EACH ROW EXECUTE FUNCTION private.guard_permissions();

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

-- Drop policies from the previous migration versions if they were installed.
DROP POLICY IF EXISTS users_select_authenticated ON public.users;
DROP POLICY IF EXISTS users_insert_self ON public.users;
DROP POLICY IF EXISTS users_update_self ON public.users;
DROP POLICY IF EXISTS users_delete_deny ON public.users;
DROP POLICY IF EXISTS documents_select_authorized ON public.documents;
DROP POLICY IF EXISTS documents_insert_owner ON public.documents;
DROP POLICY IF EXISTS documents_update_owner_and_editor ON public.documents;
DROP POLICY IF EXISTS documents_delete_only_owner ON public.documents;
DROP POLICY IF EXISTS permissions_select_owner_and_recipient ON public.permissions;
DROP POLICY IF EXISTS permissions_insert_only_owner ON public.permissions;
DROP POLICY IF EXISTS permissions_update_only_owner ON public.permissions;
DROP POLICY IF EXISTS permissions_delete_owner_or_self ON public.permissions;

CREATE POLICY users_select ON public.users FOR SELECT TO authenticated
  USING (private.firebase_uid() IS NOT NULL);
CREATE POLICY users_insert ON public.users FOR INSERT TO authenticated
  WITH CHECK (firebase_uid = private.firebase_uid() AND private.firebase_uid() IS NOT NULL);
CREATE POLICY users_update ON public.users FOR UPDATE TO authenticated
  USING (firebase_uid = private.firebase_uid())
  WITH CHECK (firebase_uid = private.firebase_uid());

CREATE POLICY documents_select ON public.documents FOR SELECT TO authenticated
  USING (owner_id = private.current_user_id() OR private.has_permission(id));
CREATE POLICY documents_insert ON public.documents FOR INSERT TO authenticated
  WITH CHECK (owner_id = private.current_user_id() AND private.current_user_id() IS NOT NULL);
CREATE POLICY documents_update ON public.documents FOR UPDATE TO authenticated
  USING (owner_id = private.current_user_id() OR private.has_permission(id, 'editor'))
  WITH CHECK (owner_id = private.current_user_id() OR private.has_permission(id, 'editor'));
CREATE POLICY documents_delete ON public.documents FOR DELETE TO authenticated
  USING (owner_id = private.current_user_id() AND private.current_user_id() IS NOT NULL);

CREATE POLICY permissions_select ON public.permissions FOR SELECT TO authenticated
  USING (user_id = private.current_user_id() OR private.is_owner(document_id));
CREATE POLICY permissions_insert ON public.permissions FOR INSERT TO authenticated
  WITH CHECK (private.is_owner(document_id) AND user_id IS DISTINCT FROM private.current_user_id());
CREATE POLICY permissions_update ON public.permissions FOR UPDATE TO authenticated
  USING (private.is_owner(document_id))
  WITH CHECK (private.is_owner(document_id));
CREATE POLICY permissions_delete ON public.permissions FOR DELETE TO authenticated
  USING (user_id = private.current_user_id() OR private.is_owner(document_id));

-- Table privileges. No direct deletes of user profiles.
REVOKE ALL ON public.users, public.documents, public.permissions FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents, public.permissions TO authenticated;

-- Restrict function execution. Trigger functions are not directly callable by clients.
REVOKE ALL ON FUNCTION private.firebase_uid() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.current_user_id() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.is_owner(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.has_permission(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.guard_users() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.guard_documents() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.guard_permissions() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.firebase_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_permission(uuid,text) TO authenticated;

-- If old public SECURITY DEFINER helpers were previously installed, close direct access.
-- Existing public helpers are NOT used by this migration.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('firebase_uid','current_user_id','is_current_user_owner',
                       'has_current_user_permission','check_file_access_permission')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.signature);
  END LOOP;
END;
$$;

COMMIT;

-- NOTE: Firebase Storage security is separate. This migration does not secure file bytes.
-- NOTE: Existing policies with DIFFERENT names are not removed; audit pg_policies before deployment.
-- NOTE: Email changes should be handled by trusted backend sync, not client UPDATE.
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
-- ==============================================================================
-- MIGRATION: 04_ensure_authenticated_role_grants.sql
-- DỰ ÁN: EduVault (LDC Edition)
--
-- MỤC ĐÍCH:
--   1. Xác nhận và củng cố toàn bộ quyền GRANT cho role `authenticated` trên
--      các bảng: public.users, public.documents, public.permissions.
--   2. Đảm bảo hàm private.firebase_uid() và private.current_user_id() thực thi
--      an toàn với JWT có claim { role: 'authenticated' } từ Firebase Third-Party Auth.
--   3. Đảm bảo RLS policies cho phép bất kỳ tài khoản Google hợp lệ nào đăng nhập
--      được tự động tạo hồ sơ của chính mình trong public.users, đọc danh sách
--      người dùng để phục vụ chia sẻ tài liệu, và quản lý tài liệu của mình.
--   4. Chống tuyệt đối việc giả mạo UID hoặc sửa đổi dữ liệu của người khác.
--
-- CÁCH CHẠY:
--   Copy toàn bộ nội dung file này và chạy trong Supabase SQL Editor (role: postgres).
-- ==============================================================================

BEGIN;

-- 1. Cấp quyền truy cập Schema
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

-- 2. Cấp quyền thao tác bảng dữ liệu cho role authenticated
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.permissions TO authenticated;

-- Thu hồi quyền từ anon và public để đảm bảo bảo mật RLS
REVOKE ALL ON public.users, public.documents, public.permissions FROM PUBLIC, anon;

-- 3. Cập nhật hàm private.firebase_uid() an toàn
CREATE OR REPLACE FUNCTION private.firebase_uid()
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT CASE 
    WHEN (SELECT auth.role()) = 'authenticated'
      THEN NULLIF(COALESCE(
        (SELECT auth.jwt()) ->> 'sub',
        (current_setting('request.jwt.claims', true)::jsonb) ->> 'sub'
      ), '')
    ELSE NULL 
  END;
$$;

-- 4. Cấp quyền thực thi các hàm bảo mật cho authenticated
GRANT EXECUTE ON FUNCTION private.firebase_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_permission(uuid, text) TO authenticated;

-- 5. Củng cố các chính sách Row Level Security (RLS) trên public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select ON public.users;
DROP POLICY IF EXISTS users_insert ON public.users;
DROP POLICY IF EXISTS users_update ON public.users;

-- Người dùng đã xác thực được xem danh sách users (để tìm kiếm email khi chia sẻ tài liệu)
CREATE POLICY users_select ON public.users FOR SELECT TO authenticated
  USING (private.firebase_uid() IS NOT NULL);

-- Người dùng chỉ được tạo hồ sơ có firebase_uid trùng với token của chính mình
CREATE POLICY users_insert ON public.users FOR INSERT TO authenticated
  WITH CHECK (firebase_uid = private.firebase_uid() AND private.firebase_uid() IS NOT NULL);

-- Người dùng chỉ được cập nhật hồ sơ của chính mình
CREATE POLICY users_update ON public.users FOR UPDATE TO authenticated
  USING (firebase_uid = private.firebase_uid())
  WITH CHECK (firebase_uid = private.firebase_uid());

COMMIT;
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
-- ==============================================================================
-- MIGRATION: 06_borrow_and_discovery_system.sql
-- DỰ ÁN: EduVault (LDC Edition)
--
-- HOÀN THIỆN NGHIỆP VỤ MƯỢN & TRẢ TÀI LIỆU VÀ KHÁM PHÁ (TH2)
-- 
-- Luồng nghiệp vụ:
--   Khám phá tài liệu -> Gửi yêu cầu mượn -> Owner duyệt/từ chối
--   -> Cấp quyền Viewer tạm thời -> Trả hoặc hết hạn -> Thu hồi quyền mượn
--
-- Các bảng & hàm:
--   1. documents: is_discoverable, is_borrowable
--   2. borrow_requests: borrower_id, owner_id, status, requested_days (1,3,7,14),
--      message, requested_at, approved_at, due_at, returned_at, updated_at
--   3. Unique partial index: Chỉ 1 yêu cầu pending/approved trên mỗi tài liệu cho mỗi người
--   4. RLS & Triggers bảo vệ toàn vẹn: Không cho giả mạo borrower_id, owner_id, status, due_at
--   5. Function has_active_borrow(document_id): Cấp quyền đọc metadata tức thì khi approved
--   6. RPC get_discoverable_documents(): Chỉ trả về metadata công khai, loại trừ tài liệu của chính mình
--   7. RPCs: create_borrow_request, approve_borrow_request, reject_borrow_request,
--            cancel_borrow_request, return_borrow_document
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- BƯỚC 1: CẬP NHẬT BẢNG PUBLIC.DOCUMENTS (is_discoverable & is_borrowable)
-- ==============================================================================

ALTER TABLE public.documents
  ADD COLUMN IF NOT EXISTS is_discoverable BOOLEAN DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS is_borrowable BOOLEAN DEFAULT false NOT NULL,
  ADD COLUMN IF NOT EXISTS tags_cache TEXT[] DEFAULT '{}'::TEXT[],
  ADD COLUMN IF NOT EXISTS location_name TEXT,
  ADD COLUMN IF NOT EXISTS building TEXT,
  ADD COLUMN IF NOT EXISTS floor TEXT,
  ADD COLUMN IF NOT EXISTS shelf TEXT,
  ADD COLUMN IF NOT EXISTS physical_location TEXT,
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_notes TEXT,
  ADD COLUMN IF NOT EXISTS is_available_for_borrow BOOLEAN DEFAULT true NOT NULL;

COMMENT ON COLUMN public.documents.is_discoverable IS 'Cho phép tài liệu hiển thị trong danh mục Khám phá công khai (mặc định tắt)';
COMMENT ON COLUMN public.documents.is_borrowable IS 'Cho phép người dùng khác gửi yêu cầu mượn tài liệu (mặc định tắt)';

CREATE INDEX IF NOT EXISTS idx_documents_discoverable ON public.documents(is_discoverable) WHERE is_discoverable = true;
CREATE INDEX IF NOT EXISTS idx_documents_borrowable ON public.documents(is_borrowable) WHERE is_borrowable = true;

-- Đảm bảo các bảng tags và document_tags tồn tại cho hệ thống gắn thẻ và khám phá tài liệu
CREATE TABLE IF NOT EXISTS public.tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  color_hex TEXT DEFAULT '#2563EB',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.document_tags (
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (document_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_document_tags_doc ON public.document_tags(document_id);
CREATE INDEX IF NOT EXISTS idx_document_tags_tag ON public.document_tags(tag_id);

ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read tags" ON public.tags;
CREATE POLICY "Authenticated users can read tags" 
  ON public.tags FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert tags" ON public.tags;
CREATE POLICY "Authenticated users can insert tags" 
  ON public.tags FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated users can read document tags" ON public.document_tags;
CREATE POLICY "Authenticated users can read document tags" 
  ON public.document_tags FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Owners can manage document tags" ON public.document_tags;
CREATE POLICY "Owners can manage document tags" 
  ON public.document_tags FOR ALL TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM public.documents d 
      WHERE d.id = document_id AND d.owner_id = private.current_user_id()
    )
  );

GRANT SELECT, INSERT ON public.tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.document_tags TO authenticated;

-- Cập nhật trigger guard_documents để Owner được cập nhật is_discoverable, is_borrowable
CREATE OR REPLACE FUNCTION private.guard_documents()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'User profile not found'; END IF;
  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
     OR NEW.updated_at IS DISTINCT FROM OLD.updated_at THEN
    RAISE EXCEPTION 'Document identity and timestamps cannot be changed';
  END IF;
  IF OLD.owner_id IS DISTINCT FROM v_user THEN
    IF NOT private.has_permission(OLD.id, 'editor') THEN
      RAISE EXCEPTION 'Editor permission required';
    END IF;
    -- Editor chỉ được sửa 4 trường metadata cơ bản, không được đổi is_discoverable, is_borrowable hay file
    IF (to_jsonb(NEW) - ARRAY['title','description','subject','category_id','updated_at'])
       IS DISTINCT FROM
       (to_jsonb(OLD) - ARRAY['title','description','subject','category_id','updated_at']) THEN
      RAISE EXCEPTION 'Editor may change only title, description, subject, category_id';
    END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


-- ==============================================================================
-- BƯỚC 2: KHỞI TẠO HOẶC CẬP NHẬT BẢNG PUBLIC.BORROW_REQUESTS
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.borrow_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  borrower_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'returned', 'expired')),
  requested_days INT NOT NULL DEFAULT 7 CHECK (requested_days IN (1, 3, 7, 14)),
  message TEXT,
  requested_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  approved_at TIMESTAMPTZ,
  due_at TIMESTAMPTZ,
  returned_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Nếu bảng đã tồn tại từ migration trước, bổ sung các cột còn thiếu
DO $$
BEGIN
  -- Cột borrower_id
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='borrower_id') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='requester_id') THEN
      ALTER TABLE public.borrow_requests ADD COLUMN borrower_id UUID REFERENCES public.users(id) ON DELETE CASCADE;
      UPDATE public.borrow_requests SET borrower_id = requester_id WHERE borrower_id IS NULL;
      ALTER TABLE public.borrow_requests ALTER COLUMN borrower_id SET NOT NULL;
    ELSE
      ALTER TABLE public.borrow_requests ADD COLUMN borrower_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
  END IF;

  -- Cột requested_days
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='requested_days') THEN
    ALTER TABLE public.borrow_requests ADD COLUMN requested_days INT NOT NULL DEFAULT 7;
  END IF;

  -- Cột message
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='message') THEN
    ALTER TABLE public.borrow_requests ADD COLUMN message TEXT;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='notes') THEN
      UPDATE public.borrow_requests SET message = notes WHERE message IS NULL;
    END IF;
  END IF;

  -- Cột requested_at
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='requested_at') THEN
    ALTER TABLE public.borrow_requests ADD COLUMN requested_at TIMESTAMPTZ DEFAULT now() NOT NULL;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='request_date') THEN
      UPDATE public.borrow_requests SET requested_at = request_date WHERE requested_at IS NULL;
    END IF;
  END IF;

  -- Cột approved_at
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='approved_at') THEN
    ALTER TABLE public.borrow_requests ADD COLUMN approved_at TIMESTAMPTZ;
  END IF;

  -- Cột due_at
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='due_at') THEN
    ALTER TABLE public.borrow_requests ADD COLUMN due_at TIMESTAMPTZ;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='due_date') THEN
      UPDATE public.borrow_requests SET due_at = due_date WHERE due_at IS NULL;
    END IF;
  END IF;

  -- Cột returned_at
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='returned_at') THEN
    ALTER TABLE public.borrow_requests ADD COLUMN returned_at TIMESTAMPTZ;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='borrow_requests' AND column_name='return_date') THEN
      UPDATE public.borrow_requests SET returned_at = return_date WHERE returned_at IS NULL;
    END IF;
  END IF;
END $$;

-- Cập nhật ràng buộc CHECK trên status để hỗ trợ đầy đủ 6 trạng thái
ALTER TABLE public.borrow_requests DROP CONSTRAINT IF EXISTS borrow_requests_status_check;
ALTER TABLE public.borrow_requests 
  ADD CONSTRAINT borrow_requests_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'returned', 'expired'));

-- Cập nhật ràng buộc CHECK trên requested_days (1, 3, 7, 14 ngày)
ALTER TABLE public.borrow_requests DROP CONSTRAINT IF EXISTS borrow_requests_requested_days_check;
ALTER TABLE public.borrow_requests 
  ADD CONSTRAINT borrow_requests_requested_days_check 
  CHECK (requested_days IN (1, 3, 7, 14));

-- Ràng buộc quan trọng: Mỗi người chỉ được có MỘT yêu cầu pending hoặc approved trên cùng một tài liệu
CREATE UNIQUE INDEX IF NOT EXISTS idx_borrow_requests_active_unique 
  ON public.borrow_requests (document_id, borrower_id) 
  WHERE status IN ('pending', 'approved');

CREATE INDEX IF NOT EXISTS idx_borrow_requests_document_id ON public.borrow_requests(document_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_borrower_id ON public.borrow_requests(borrower_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_owner_id ON public.borrow_requests(owner_id);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_status ON public.borrow_requests(status);
CREATE INDEX IF NOT EXISTS idx_borrow_requests_due_at ON public.borrow_requests(due_at) WHERE status = 'approved';

COMMENT ON TABLE public.borrow_requests IS 'Quản lý toàn diện quy trình mượn - trả tài liệu số và bản cứng (EduVault LDC Edition)';


-- ==============================================================================
-- BƯỚC 3: KIỂM SOÁT QUYỀN TRUY CẬP (ACTIVE BORROW HELPER & RLS)
-- ==============================================================================

-- Hàm kiểm tra người dùng hiện tại có lượt mượn đang active (approved, còn hạn, chưa trả)
CREATE OR REPLACE FUNCTION private.has_active_borrow(p_document_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.borrow_requests AS br
    WHERE br.document_id = p_document_id
      AND br.borrower_id = private.current_user_id()
      AND br.status = 'approved'
      AND br.due_at > now()
      AND br.returned_at IS NULL
  );
$$;

-- Cập nhật RLS Policy trên public.documents để người mượn hợp lệ được đọc metadata
DROP POLICY IF EXISTS documents_select ON public.documents;
CREATE POLICY documents_select ON public.documents FOR SELECT TO authenticated
  USING (
    owner_id = private.current_user_id() 
    OR private.has_permission(id)
    OR private.has_active_borrow(id)
  );

-- Bật RLS trên borrow_requests
ALTER TABLE public.borrow_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS borrow_requests_select ON public.borrow_requests;
CREATE POLICY borrow_requests_select ON public.borrow_requests FOR SELECT TO authenticated
  USING (
    borrower_id = private.current_user_id() 
    OR owner_id = private.current_user_id()
  );

DROP POLICY IF EXISTS borrow_requests_insert ON public.borrow_requests;
CREATE POLICY borrow_requests_insert ON public.borrow_requests FOR INSERT TO authenticated
  WITH CHECK (
    borrower_id = private.current_user_id() 
    AND borrower_id <> owner_id
    AND status = 'pending'
  );

DROP POLICY IF EXISTS borrow_requests_update ON public.borrow_requests;
CREATE POLICY borrow_requests_update ON public.borrow_requests FOR UPDATE TO authenticated
  USING (
    borrower_id = private.current_user_id() 
    OR owner_id = private.current_user_id()
  );


-- ==============================================================================
-- BƯỚC 4: TRIGGER BẢO VỆ TOÀN VẸN BORROW_REQUESTS (ANTI-TAMPERING)
-- ==============================================================================

CREATE OR REPLACE FUNCTION private.guard_borrow_requests()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user uuid;
  v_doc_owner uuid;
  v_is_borrowable boolean;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated user profile not found';
  END IF;

  -- Thao tác INSERT: Tạo yêu cầu mới
  IF TG_OP = 'INSERT' THEN
    -- Xác thực tài liệu và lấy thông tin chủ sở hữu thật từ database
    SELECT owner_id, is_borrowable INTO v_doc_owner, v_is_borrowable
    FROM public.documents WHERE id = NEW.document_id;

    IF v_doc_owner IS NULL THEN
      RAISE EXCEPTION 'Tài liệu không tồn tại';
    END IF;

    IF NOT v_is_borrowable THEN
      RAISE EXCEPTION 'Tài liệu này không cho phép mượn';
    END IF;

    -- Luôn tự động gắn borrower_id từ token, không tin tưởng client
    NEW.borrower_id := v_user;
    NEW.owner_id := v_doc_owner;

    IF NEW.borrower_id = NEW.owner_id THEN
      RAISE EXCEPTION 'Bạn không thể mượn tài liệu của chính mình';
    END IF;

    -- Bắt buộc trạng thái khởi tạo là pending
    NEW.status := 'pending';
    NEW.requested_at := now();
    NEW.approved_at := NULL;
    NEW.due_at := NULL;
    NEW.returned_at := NULL;
    NEW.updated_at := now();

    -- Hỗ trợ tương thích ngược với code cũ nếu có đọc requester_id / notes / request_date
    BEGIN
      NEW.requester_id := NEW.borrower_id;
      NEW.request_date := NEW.requested_at;
      NEW.notes := NEW.message;
    EXCEPTION WHEN OTHERS THEN
      -- Nếu cột cũ không tồn tại thì bỏ qua
    END;

    RETURN NEW;
  END IF;

  -- Thao tác UPDATE: Cập nhật trạng thái
  IF TG_OP = 'UPDATE' THEN
    -- Khóa bất biến các trường định danh
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.document_id IS DISTINCT FROM OLD.document_id
       OR NEW.borrower_id IS DISTINCT FROM OLD.borrower_id
       OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
       OR NEW.requested_days IS DISTINCT FROM OLD.requested_days
       OR NEW.requested_at IS DISTINCT FROM OLD.requested_at THEN
      RAISE EXCEPTION 'Các trường định danh yêu cầu mượn không thể bị thay đổi';
    END IF;

    -- 1. Nếu duyệt (pending -> approved)
    IF OLD.status = 'pending' AND NEW.status = 'approved' THEN
      IF v_user IS DISTINCT FROM OLD.owner_id THEN
        RAISE EXCEPTION 'Chỉ chủ sở hữu tài liệu mới có quyền phê duyệt yêu cầu mượn';
      END IF;
      NEW.approved_at := now();
      NEW.due_at := now() + (OLD.requested_days || ' days')::interval;
      NEW.returned_at := NULL;
    
    -- 2. Nếu từ chối (pending -> rejected)
    ELSIF OLD.status = 'pending' AND NEW.status = 'rejected' THEN
      IF v_user IS DISTINCT FROM OLD.owner_id THEN
        RAISE EXCEPTION 'Chỉ chủ sở hữu tài liệu mới có quyền từ chối yêu cầu mượn';
      END IF;
      NEW.approved_at := NULL;
      NEW.due_at := NULL;
      NEW.returned_at := NULL;

    -- 3. Nếu người mượn hủy khi đang pending (pending -> cancelled)
    ELSIF OLD.status = 'pending' AND NEW.status = 'cancelled' THEN
      IF v_user IS DISTINCT FROM OLD.borrower_id THEN
        RAISE EXCEPTION 'Chỉ người gửi yêu cầu mới có quyền hủy yêu cầu mượn';
      END IF;
      NEW.approved_at := NULL;
      NEW.due_at := NULL;
      NEW.returned_at := NULL;

    -- 4. Nếu trả tài liệu (approved -> returned)
    ELSIF OLD.status = 'approved' AND NEW.status = 'returned' THEN
      IF v_user IS DISTINCT FROM OLD.borrower_id AND v_user IS DISTINCT FROM OLD.owner_id THEN
        RAISE EXCEPTION 'Chỉ người mượn hoặc chủ sở hữu mới có quyền ghi nhận trả tài liệu';
      END IF;
      NEW.returned_at := now();

    -- 5. Đánh dấu hết hạn (approved -> expired)
    ELSIF OLD.status = 'approved' AND NEW.status = 'expired' THEN
      IF OLD.due_at IS NOT NULL AND OLD.due_at > now() THEN
        RAISE EXCEPTION 'Lượt mượn chưa đến ngày hết hạn';
      END IF;

    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
      RAISE EXCEPTION 'Chuyển đổi trạng thái từ % sang % không hợp lệ', OLD.status, NEW.status;
    END IF;

    NEW.updated_at := now();

    -- Cập nhật tương thích ngược
    BEGIN
      NEW.due_date := NEW.due_at;
      NEW.return_date := NEW.returned_at;
    EXCEPTION WHEN OTHERS THEN
    END;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS eduvault_guard_borrow_requests ON public.borrow_requests;
CREATE TRIGGER eduvault_guard_borrow_requests
  BEFORE INSERT OR UPDATE ON public.borrow_requests
  FOR EACH ROW EXECUTE FUNCTION private.guard_borrow_requests();


-- ==============================================================================
-- BƯỚC 5: RPC KHÁM PHÁ TÀI LIỆU AN TOÀN (PUBLIC DISCOVERY METADATA ONLY)
-- ==============================================================================

-- Hàm trả về danh sách tài liệu công khai có bật is_discoverable = true,
-- LOẠI TRỪ tài liệu của chính người đang đăng nhập,
-- và CHỈ trả về metadata công khai (KHÔNG lộ storage_path hay tệp nhạy cảm).
CREATE OR REPLACE FUNCTION public.get_discoverable_documents(
  p_search TEXT DEFAULT NULL,
  p_subject TEXT DEFAULT NULL,
  p_category_id TEXT DEFAULT NULL,
  p_tag TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  subject TEXT,
  category_id TEXT,
  is_borrowable BOOLEAN,
  tags TEXT[],
  location_name TEXT,
  building TEXT,
  floor TEXT,
  shelf TEXT,
  created_at TIMESTAMPTZ,
  owner_id UUID,
  owner_name TEXT,
  owner_email TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT 
    d.id,
    d.title,
    d.description,
    d.subject,
    d.category_id,
    d.is_borrowable,
    COALESCE(
      NULLIF(d.tags_cache, '{}'::TEXT[]),
      ARRAY(
        SELECT t.name 
        FROM public.document_tags dt 
        JOIN public.tags t ON t.id = dt.tag_id 
        WHERE dt.document_id = d.id
      ), 
      ARRAY[]::TEXT[]
    ) AS tags,
    d.location_name,
    d.building,
    d.floor,
    d.shelf,
    d.created_at,
    d.owner_id,
    u.display_name AS owner_name,
    u.email AS owner_email
  FROM public.documents d
  JOIN public.users u ON u.id = d.owner_id
  WHERE d.is_discoverable = true
    -- Không hiển thị tài liệu của chính mình trong màn hình Khám phá
    AND d.owner_id <> COALESCE(private.current_user_id(), '00000000-0000-0000-0000-000000000000'::uuid)
    -- Lọc theo từ khóa tìm kiếm (tiêu đề, môn học, mô tả)
    AND (
      p_search IS NULL 
      OR btrim(p_search) = '' 
      OR d.title ILIKE '%' || btrim(p_search) || '%'
      OR d.subject ILIKE '%' || btrim(p_search) || '%'
      OR d.description ILIKE '%' || btrim(p_search) || '%'
    )
    -- Lọc theo môn học
    AND (
      p_subject IS NULL 
      OR btrim(p_subject) = '' 
      OR d.subject ILIKE '%' || btrim(p_subject) || '%'
    )
    -- Lọc theo danh mục
    AND (
      p_category_id IS NULL 
      OR p_category_id = 'all' 
      OR d.category_id = p_category_id
    )
    -- Lọc theo tag (hỗ trợ cả tags_cache và document_tags)
    AND (
      p_tag IS NULL 
      OR btrim(p_tag) = '' 
      OR (d.tags_cache IS NOT NULL AND btrim(p_tag) = ANY(d.tags_cache))
      OR EXISTS (
        SELECT 1 
        FROM public.document_tags dt 
        JOIN public.tags t ON t.id = dt.tag_id 
        WHERE dt.document_id = d.id AND t.name ILIKE btrim(p_tag)
      )
    )
  ORDER BY d.created_at DESC;
$$;


-- ==============================================================================
-- BƯỚC 6: RPCS QUẢN LÝ NGHIỆP VỤ MƯỢN / TRẢ NGUYÊN TỬ (ATOMIC BORROW RPCs)
-- ==============================================================================

-- 6.1. Gửi yêu cầu mượn tài liệu
CREATE OR REPLACE FUNCTION public.create_borrow_request(
  p_document_id UUID,
  p_requested_days INT DEFAULT 7,
  p_message TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_doc record;
  v_new_id uuid;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Vui lòng đăng nhập để thực hiện thao tác';
  END IF;

  SELECT * INTO v_doc FROM public.documents WHERE id = p_document_id;
  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Tài liệu không tồn tại';
  END IF;

  IF NOT v_doc.is_borrowable THEN
    RAISE EXCEPTION 'Tài liệu này không cho phép mượn';
  END IF;

  IF v_doc.owner_id = v_user THEN
    RAISE EXCEPTION 'Bạn không thể gửi yêu cầu mượn tài liệu của chính mình';
  END IF;

  IF p_requested_days NOT IN (1, 3, 7, 14) THEN
    RAISE EXCEPTION 'Thời hạn mượn chỉ chấp nhận: 1, 3, 7 hoặc 14 ngày';
  END IF;

  -- Kiểm tra xem đã có yêu cầu pending hoặc approved đang hoạt động chưa
  IF EXISTS (
    SELECT 1 FROM public.borrow_requests
    WHERE document_id = p_document_id 
      AND borrower_id = v_user 
      AND status IN ('pending', 'approved')
  ) THEN
    RAISE EXCEPTION 'Bạn đã có một yêu cầu đang chờ duyệt hoặc một lượt mượn đang hoạt động cho tài liệu này';
  END IF;

  INSERT INTO public.borrow_requests (
    document_id,
    borrower_id,
    owner_id,
    status,
    requested_days,
    message
  ) VALUES (
    p_document_id,
    v_user,
    v_doc.owner_id,
    'pending',
    p_requested_days,
    p_message
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_new_id,
    'message', 'Đã gửi yêu cầu mượn tài liệu thành công'
  );
END;
$$;

-- 6.2. Phê duyệt yêu cầu mượn (Chỉ Owner)
CREATE OR REPLACE FUNCTION public.approve_borrow_request(p_request_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_req record;
  v_due_at timestamptz;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'Vui lòng đăng nhập'; END IF;

  SELECT * INTO v_req FROM public.borrow_requests WHERE id = p_request_id;
  IF v_req.id IS NULL THEN RAISE EXCEPTION 'Yêu cầu mượn không tồn tại'; END IF;

  IF v_req.owner_id <> v_user THEN
    RAISE EXCEPTION 'Chỉ chủ sở hữu tài liệu mới có quyền phê duyệt';
  END IF;

  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Chỉ có thể phê duyệt yêu cầu đang ở trạng thái chờ duyệt (pending)';
  END IF;

  v_due_at := now() + (v_req.requested_days || ' days')::interval;

  UPDATE public.borrow_requests
  SET 
    status = 'approved',
    approved_at = now(),
    due_at = v_due_at,
    updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'approved',
    'due_at', v_due_at,
    'message', 'Đã phê duyệt yêu cầu mượn thành công'
  );
END;
$$;

-- 6.3. Từ chối yêu cầu mượn (Chỉ Owner)
CREATE OR REPLACE FUNCTION public.reject_borrow_request(
  p_request_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_req record;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'Vui lòng đăng nhập'; END IF;

  SELECT * INTO v_req FROM public.borrow_requests WHERE id = p_request_id;
  IF v_req.id IS NULL THEN RAISE EXCEPTION 'Yêu cầu mượn không tồn tại'; END IF;

  IF v_req.owner_id <> v_user THEN
    RAISE EXCEPTION 'Chỉ chủ sở hữu tài liệu mới có quyền từ chối';
  END IF;

  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Chỉ có thể từ chối yêu cầu đang ở trạng thái chờ duyệt (pending)';
  END IF;

  UPDATE public.borrow_requests
  SET 
    status = 'rejected',
    updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'rejected',
    'message', 'Đã từ chối yêu cầu mượn'
  );
END;
$$;

-- 6.4. Hủy yêu cầu mượn (Chỉ người gửi khi đang pending)
CREATE OR REPLACE FUNCTION public.cancel_borrow_request(p_request_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_req record;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'Vui lòng đăng nhập'; END IF;

  SELECT * INTO v_req FROM public.borrow_requests WHERE id = p_request_id;
  IF v_req.id IS NULL THEN RAISE EXCEPTION 'Yêu cầu mượn không tồn tại'; END IF;

  IF v_req.borrower_id <> v_user THEN
    RAISE EXCEPTION 'Chỉ người mượn mới có quyền hủy yêu cầu';
  END IF;

  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Chỉ có thể hủy yêu cầu đang ở trạng thái chờ duyệt (pending)';
  END IF;

  UPDATE public.borrow_requests
  SET 
    status = 'cancelled',
    updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'cancelled',
    'message', 'Đã hủy yêu cầu mượn tài liệu'
  );
END;
$$;

-- 6.5. Trả tài liệu (Người mượn trả sớm hoặc Chủ sở hữu nhận lại sách)
CREATE OR REPLACE FUNCTION public.return_borrow_document(p_request_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_req record;
BEGIN
  v_user := private.current_user_id();
  IF v_user IS NULL THEN RAISE EXCEPTION 'Vui lòng đăng nhập'; END IF;

  SELECT * INTO v_req FROM public.borrow_requests WHERE id = p_request_id;
  IF v_req.id IS NULL THEN RAISE EXCEPTION 'Lượt mượn không tồn tại'; END IF;

  IF v_req.borrower_id <> v_user AND v_req.owner_id <> v_user THEN
    RAISE EXCEPTION 'Chỉ người mượn hoặc chủ sở hữu mới có quyền ghi nhận trả tài liệu';
  END IF;

  IF v_req.status <> 'approved' THEN
    RAISE EXCEPTION 'Chỉ có thể trả tài liệu đang trong trạng thái được mượn (approved)';
  END IF;

  UPDATE public.borrow_requests
  SET 
    status = 'returned',
    returned_at = now(),
    updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'returned',
    'returned_at', now(),
    'message', 'Đã hoàn trả tài liệu thành công. Quyền đọc tạm thời chấm dứt.'
  );
END;
$$;


-- ==============================================================================
-- BƯỚC 7: CẤP QUYỀN THI HÀNH (GRANTS CHO ROLE AUTHENTICATED)
-- ==============================================================================

GRANT SELECT, INSERT, UPDATE ON public.borrow_requests TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_discoverable_documents TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_borrow_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_borrow_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_borrow_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_borrow_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.return_borrow_document TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_active_borrow TO authenticated;

-- ==============================================================================
-- BƯỚC 8: CẤU HÌNH SUPABASE STORAGE (BUCKET 'documents' MIỄN PHÍ KHÔNG CẦN THẺ)
-- ==============================================================================

-- Tự động tạo bucket 'documents' công khai cho phép lưu trữ tệp tài liệu
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('documents', 'documents', true, 52428800, null)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Cho phép đọc tệp công khai
DROP POLICY IF EXISTS "Public Read Documents" ON storage.objects;
CREATE POLICY "Public Read Documents" ON storage.objects FOR SELECT USING (bucket_id = 'documents');

-- Cho phép người dùng tải lên, cập nhật và xóa tệp trong bucket 'documents'
DROP POLICY IF EXISTS "Allow Upload Documents" ON storage.objects;
CREATE POLICY "Allow Upload Documents" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'documents');

DROP POLICY IF EXISTS "Allow Update Documents" ON storage.objects;
CREATE POLICY "Allow Update Documents" ON storage.objects FOR UPDATE USING (bucket_id = 'documents');

DROP POLICY IF EXISTS "Allow Delete Documents" ON storage.objects;
CREATE POLICY "Allow Delete Documents" ON storage.objects FOR DELETE USING (bucket_id = 'documents');

COMMIT;
