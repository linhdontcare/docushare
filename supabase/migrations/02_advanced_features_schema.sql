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
