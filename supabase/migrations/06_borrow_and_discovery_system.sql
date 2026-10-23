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

COMMIT;
