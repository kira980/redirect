# Multi-Tenant Setup For Your Current Database

Your database is already multi-tenant. The tenant table is:

- `restaurant`

And these tables already belong to a tenant through `restaurant_id`:

- `categories.restaurant_id`
- `menu_items.restaurant_id`
- `settings.restaurant_id`

So you do not need a separate `businesses` table. In this project, "business" means one row in `restaurant`.

## How The App Chooses A Business

The updated app resolves the current restaurant first, then uses its `id` in every menu query.

Use either URL parameter:

```text
index.html?restaurant=lastella-bakery
admin0.html?restaurant=lastella-bakery
```

or:

```text
index.html?slug=lastella-bakery
admin0.html?slug=lastella-bakery
```

If no slug is passed, the public menu loads the first active restaurant. The admin tries to load the first active restaurant owned by the logged-in user.

## Required Query Pattern

Every tenant-owned table must be filtered with the active restaurant ID:

```js
const { data: restaurant } = await db
  .from('restaurant')
  .select('id,name,slug')
  .eq('slug', restaurantSlug)
  .eq('is_active', true)
  .maybeSingle();

const restaurantId = restaurant.id;

const categories = await db
  .from('categories')
  .select('*')
  .eq('restaurant_id', restaurantId)
  .eq('is_active', true)
  .order('sort_order', { ascending: true });

const items = await db
  .from('menu_items')
  .select('*')
  .eq('restaurant_id', restaurantId)
  .eq('is_available', true)
  .order('sort_order', { ascending: true });

const settings = await db
  .from('settings')
  .select('value')
  .eq('restaurant_id', restaurantId)
  .eq('key', 'meal_offers')
  .maybeSingle();
```

## Settings Save

Your `settings` primary key is `(restaurant_id, key)`, so upserts must use the same conflict target:

```js
await db.from('settings').upsert(
  {
    restaurant_id: restaurantId,
    key: 'meal_offers',
    value,
    updated_at: new Date().toISOString()
  },
  { onConflict: 'restaurant_id,key' }
);
```

## Admin Writes

Admin inserts and updates must include `restaurant_id` in the payload:

```js
const payload = {
  restaurant_id: restaurantId,
  category_id,
  name_ar,
  price,
  is_available: true
};
```

Updates and deletes should also guard by both `id` and `restaurant_id`:

```js
await db
  .from('menu_items')
  .update(payload)
  .eq('id', itemId)
  .eq('restaurant_id', restaurantId);
```

That way, even if an ID from another restaurant is accidentally used, the query will not touch it.

## Recommended RLS Direction

Frontend filtering is not enough by itself. Supabase Row Level Security should also enforce tenant boundaries.

For public reads, allow active rows from active restaurants:

```sql
exists (
  select 1
  from public.restaurant r
  where r.id = categories.restaurant_id
    and r.is_active = true
)
```

For admin writes, use either:

- `restaurant.owner_id = auth.uid()`
- or a join table like `restaurant_admins` if multiple admins can manage one restaurant.

If you keep only `admin_users`, every admin is global. That works for one trusted operator, but it is not enough if different businesses should manage only their own menu.
