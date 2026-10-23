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