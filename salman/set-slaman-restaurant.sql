-- Ensure this menu points at the slaman restaurant tenant.
UPDATE public.restaurant
SET
  slug = 'slaman',
  menu_url = '/index.html?restaurant=slaman'
WHERE id = '4927c28a-a89e-4339-9eea-cd97e10bb0ab';

-- Check the row:
SELECT id, name, slug, menu_url, is_active
FROM public.restaurant
WHERE id = '4927c28a-a89e-4339-9eea-cd97e10bb0ab';
