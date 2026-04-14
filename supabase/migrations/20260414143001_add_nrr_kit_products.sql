begin;

alter table if exists public.kit_products
  add column if not exists stock_os integer not null default 0;

update public.kit_products
set price = 25.00,
    stripe_url = ''
where category = 'race' and product_name = 'Drylite Vest';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'race',
  'Drylite Vest',
  25.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'race' and product_name = 'Drylite Vest'
);

update public.kit_products
set price = 25.00,
    stripe_url = ''
where category = 'race' and product_name = 'Drylite T-shirt';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'race',
  'Drylite T-shirt',
  25.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'race' and product_name = 'Drylite T-shirt'
);

update public.kit_products
set price = 20.00,
    stripe_url = ''
where category = 'race' and product_name = 'Scimitar Vest';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'race',
  'Scimitar Vest',
  20.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'race' and product_name = 'Scimitar Vest'
);

update public.kit_products
set price = 22.00,
    stripe_url = ''
where category = 'race' and product_name = 'Scimitar T-Shirt';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'race',
  'Scimitar T-Shirt',
  22.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'race' and product_name = 'Scimitar T-Shirt'
);

update public.kit_products
set price = 25.00,
    stripe_url = ''
where category = 'training' and product_name = 'Training T-shirt';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'training',
  'Training T-shirt',
  25.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'training' and product_name = 'Training T-shirt'
);

update public.kit_products
set price = 35.00,
    stripe_url = ''
where category = 'leisure' and product_name = 'Hoodie';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'leisure',
  'Hoodie',
  35.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'leisure' and product_name = 'Hoodie'
);

update public.kit_products
set price = 5.00,
    stripe_url = ''
where category = 'leisure' and product_name = 'Buff';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'leisure',
  'Buff',
  5.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'leisure' and product_name = 'Buff'
);

update public.kit_products
set price = 5.00,
    stripe_url = ''
where category = 'leisure' and product_name = 'Beanie';

insert into public.kit_products (
  category,
  product_name,
  price,
  stripe_url,
  stock_xs,
  stock_s,
  stock_m,
  stock_l,
  stock_xl,
  stock_xxl,
  stock_os
)
select
  'leisure',
  'Beanie',
  5.00,
  '',
  0, 0, 0, 0, 0, 0,
  0
where not exists (
  select 1 from public.kit_products
  where category = 'leisure' and product_name = 'Beanie'
);

commit;
