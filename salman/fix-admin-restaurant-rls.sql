-- Fix admin saves for the tenant-based restaurant schema.
-- Run this in Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users au
    WHERE au.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_restaurant(p_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.restaurant r
      WHERE r.id = p_id
        AND r.owner_id = auth.uid()
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_manage_restaurant(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_restaurant(uuid) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.can_manage_storage_object(object_name text)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.restaurant r
      WHERE (
          r.id::text = split_part(object_name, '/', 1)
          OR r.slug = split_part(object_name, '/', 1)
          OR (
            split_part(object_name, '/', 1) = 'salman'
            AND r.id = '4927c28a-a89e-4339-9eea-cd97e10bb0ab'
          )
        )
        AND r.owner_id = auth.uid()
    );
$$;

REVOKE ALL ON FUNCTION public.can_manage_storage_object(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_storage_object(text) TO anon, authenticated;

ALTER TABLE public.restaurant ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "restaurant_select" ON public.restaurant;
DROP POLICY IF EXISTS "restaurant_insert" ON public.restaurant;
DROP POLICY IF EXISTS "restaurant_update" ON public.restaurant;
DROP POLICY IF EXISTS "restaurant_delete" ON public.restaurant;

CREATE POLICY "restaurant_select" ON public.restaurant FOR SELECT
  USING (is_active = true OR public.can_manage_restaurant(id));

CREATE POLICY "restaurant_insert" ON public.restaurant FOR INSERT
  WITH CHECK (public.is_admin() OR owner_id = auth.uid());

CREATE POLICY "restaurant_update" ON public.restaurant FOR UPDATE
  USING (public.can_manage_restaurant(id))
  WITH CHECK (public.can_manage_restaurant(id));

CREATE POLICY "restaurant_delete" ON public.restaurant FOR DELETE
  USING (public.can_manage_restaurant(id));

DROP POLICY IF EXISTS "categories_select" ON public.categories;
DROP POLICY IF EXISTS "categories_insert" ON public.categories;
DROP POLICY IF EXISTS "categories_update" ON public.categories;
DROP POLICY IF EXISTS "categories_delete" ON public.categories;

CREATE POLICY "categories_select" ON public.categories FOR SELECT
  USING (
    public.can_manage_restaurant(restaurant_id)
    OR (
      is_active = true
      AND EXISTS (
        SELECT 1
        FROM public.restaurant r
        WHERE r.id = categories.restaurant_id
          AND r.is_active = true
      )
    )
  );

CREATE POLICY "categories_insert" ON public.categories FOR INSERT
  WITH CHECK (public.can_manage_restaurant(restaurant_id));

CREATE POLICY "categories_update" ON public.categories FOR UPDATE
  USING (public.can_manage_restaurant(restaurant_id))
  WITH CHECK (public.can_manage_restaurant(restaurant_id));

CREATE POLICY "categories_delete" ON public.categories FOR DELETE
  USING (public.can_manage_restaurant(restaurant_id));

DROP POLICY IF EXISTS "items_select" ON public.menu_items;
DROP POLICY IF EXISTS "items_insert" ON public.menu_items;
DROP POLICY IF EXISTS "items_update" ON public.menu_items;
DROP POLICY IF EXISTS "items_delete" ON public.menu_items;

CREATE POLICY "items_select" ON public.menu_items FOR SELECT
  USING (
    public.can_manage_restaurant(restaurant_id)
    OR (
      is_available = true
      AND EXISTS (
        SELECT 1
        FROM public.categories c
        JOIN public.restaurant r ON r.id = c.restaurant_id
        WHERE c.id = menu_items.category_id
          AND c.restaurant_id = menu_items.restaurant_id
          AND c.is_active = true
          AND r.is_active = true
      )
    )
  );

CREATE POLICY "items_insert" ON public.menu_items FOR INSERT
  WITH CHECK (
    public.can_manage_restaurant(restaurant_id)
    AND EXISTS (
      SELECT 1
      FROM public.categories c
      WHERE c.id = menu_items.category_id
        AND c.restaurant_id = menu_items.restaurant_id
    )
  );

CREATE POLICY "items_update" ON public.menu_items FOR UPDATE
  USING (public.can_manage_restaurant(restaurant_id))
  WITH CHECK (
    public.can_manage_restaurant(restaurant_id)
    AND EXISTS (
      SELECT 1
      FROM public.categories c
      WHERE c.id = menu_items.category_id
        AND c.restaurant_id = menu_items.restaurant_id
    )
  );

CREATE POLICY "items_delete" ON public.menu_items FOR DELETE
  USING (public.can_manage_restaurant(restaurant_id));

DROP POLICY IF EXISTS "settings_select" ON public.settings;
DROP POLICY IF EXISTS "settings_insert" ON public.settings;
DROP POLICY IF EXISTS "settings_update" ON public.settings;
DROP POLICY IF EXISTS "settings_delete" ON public.settings;

CREATE POLICY "settings_select" ON public.settings FOR SELECT
  USING (
    public.can_manage_restaurant(restaurant_id)
    OR (
      key = 'meal_offers'
      AND EXISTS (
        SELECT 1
        FROM public.restaurant r
        WHERE r.id = settings.restaurant_id
          AND r.is_active = true
      )
    )
  );

CREATE POLICY "settings_insert" ON public.settings FOR INSERT
  WITH CHECK (public.can_manage_restaurant(restaurant_id));

CREATE POLICY "settings_update" ON public.settings FOR UPDATE
  USING (public.can_manage_restaurant(restaurant_id))
  WITH CHECK (public.can_manage_restaurant(restaurant_id));

CREATE POLICY "settings_delete" ON public.settings FOR DELETE
  USING (public.can_manage_restaurant(restaurant_id));

DROP POLICY IF EXISTS "images_select" ON storage.objects;
DROP POLICY IF EXISTS "images_insert" ON storage.objects;
DROP POLICY IF EXISTS "images_update" ON storage.objects;
DROP POLICY IF EXISTS "images_delete" ON storage.objects;

CREATE POLICY "images_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'images');

CREATE POLICY "images_insert" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'images'
    AND public.can_manage_storage_object(name)
  );

CREATE POLICY "images_update" ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'images'
    AND public.can_manage_storage_object(name)
  )
  WITH CHECK (
    bucket_id = 'images'
    AND public.can_manage_storage_object(name)
  );

CREATE POLICY "images_delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'images'
    AND public.can_manage_storage_object(name)
  );

DROP POLICY IF EXISTS "backups_select" ON storage.objects;
DROP POLICY IF EXISTS "backups_insert" ON storage.objects;
DROP POLICY IF EXISTS "backups_update" ON storage.objects;
DROP POLICY IF EXISTS "backups_delete" ON storage.objects;

CREATE POLICY "backups_select" ON storage.objects FOR SELECT
  USING (
    bucket_id = 'backups'
    AND public.can_manage_storage_object(name)
  );

CREATE POLICY "backups_insert" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'backups'
    AND public.can_manage_storage_object(name)
  );

CREATE POLICY "backups_update" ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'backups'
    AND public.can_manage_storage_object(name)
  )
  WITH CHECK (
    bucket_id = 'backups'
    AND public.can_manage_storage_object(name)
  );

CREATE POLICY "backups_delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'backups'
    AND public.can_manage_storage_object(name)
  );

-- Optional: make the current logged-in admin own the slaman restaurant if needed.
-- Run this manually while logged in as the intended owner, or replace auth.uid()
-- with a concrete auth.users.id.
-- UPDATE public.restaurant
-- SET owner_id = auth.uid()
-- WHERE id = '4927c28a-a89e-4339-9eea-cd97e10bb0ab'
--   AND owner_id IS NULL;

NOTIFY pgrst, 'reload schema';
