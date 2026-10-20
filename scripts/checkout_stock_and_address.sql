begin;

alter table public.orders
  add column if not exists delivery_municipality text,
  add column if not exists delivery_municipality_code text,
  add column if not exists delivery_barangay text,
  add column if not exists delivery_barangay_code text,
  add column if not exists delivery_landmark text,
  add column if not exists checkout_request_id text;

create unique index if not exists orders_customer_checkout_request_id_key
  on public.orders (customer_id, checkout_request_id)
  where checkout_request_id is not null;

alter table public.products replica identity full;
alter table public.orders replica identity full;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'products'
  ) then
    execute 'alter publication supabase_realtime add table public.products';
  end if;
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'orders'
  ) then
    execute 'alter publication supabase_realtime add table public.orders';
  end if;
end
$$;

create or replace function public.place_order_with_stock(
  p_payment_method text,
  p_delivery_name text,
  p_delivery_phone text,
  p_municipality_code text,
  p_municipality text,
  p_barangay_code text,
  p_barangay text,
  p_landmark text,
  p_delivery_notes text,
  p_items jsonb,
  p_checkout_request_id text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_item record;
  v_product_name text;
  v_unit_price numeric;
  v_subtotal numeric := 0;
  v_delivery_fee numeric := 0;
  v_order_id uuid;
begin
  if v_customer_id is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  if p_checkout_request_id is null or length(trim(p_checkout_request_id)) not between 1 and 128 then
    raise exception 'CHECKOUT_REQUEST_ID_REQUIRED';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_customer_id::text || ':' || p_checkout_request_id, 0)
  );

  select orders.id
    into v_order_id
  from public.orders as orders
  where orders.customer_id = v_customer_id
    and orders.checkout_request_id = p_checkout_request_id;

  if found then
    return v_order_id;
  end if;

    if p_payment_method is null
      or p_payment_method not in ('cod', 'paymongo') then
    raise exception 'INVALID_PAYMENT_METHOD';
  end if;

  if p_municipality_code is null
     or p_barangay_code is null
     or p_municipality_code !~ '^0712[0-9]{5}$'
     or p_barangay_code !~ '^0712[0-9]{5}$'
     or left(p_municipality_code, 6) <> left(p_barangay_code, 6) then
    raise exception 'DELIVERY_AREA_MUST_BE_IN_BOHOL';
  end if;

  if p_municipality is null or trim(p_municipality) = ''
     or p_barangay is null or trim(p_barangay) = ''
     or p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'DELIVERY_DETAILS_AND_ORDER_ITEMS_REQUIRED';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'ORDER_ITEMS_REQUIRED';
  end if;

  for v_item in
    select
      (item.value ->> 'product_id')::uuid as product_id,
      sum((item.value ->> 'quantity')::integer)::integer as quantity
    from jsonb_array_elements(p_items) as item(value)
    group by (item.value ->> 'product_id')::uuid
    order by (item.value ->> 'product_id')::uuid
  loop
    if v_item.quantity is null or v_item.quantity < 1 then
      raise exception 'INVALID_ORDER_QUANTITY';
    end if;

    update public.products as product
    set stock_quantity = product.stock_quantity - v_item.quantity
    where product.id = v_item.product_id
      and product.is_active = true
      and product.stock_quantity >= v_item.quantity
    returning product.name, product.price
      into v_product_name, v_unit_price;

    if not found then
      raise exception 'INSUFFICIENT_STOCK: product %', v_item.product_id;
    end if;

    v_subtotal := v_subtotal + (v_unit_price * v_item.quantity);
  end loop;

  insert into public.orders (
    customer_id,
    status,
    payment_method,
    payment_status,
    subtotal,
    delivery_fee,
    total,
    delivery_name,
    delivery_phone,
    delivery_address,
    delivery_municipality,
    delivery_municipality_code,
    delivery_barangay,
    delivery_barangay_code,
    delivery_landmark,
    delivery_notes,
    checkout_request_id
  ) values (
    v_customer_id,
    'pending',
    p_payment_method,
    case when p_payment_method = 'cod' then 'pending' else 'unpaid' end,
    v_subtotal,
    v_delivery_fee,
    v_subtotal + v_delivery_fee,
    p_delivery_name,
    p_delivery_phone,
    format('%s, %s, Bohol', p_barangay, p_municipality),
    p_municipality,
    p_municipality_code,
    p_barangay,
    p_barangay_code,
    nullif(trim(p_landmark), ''),
    nullif(trim(p_delivery_notes), ''),
    p_checkout_request_id
  ) returning id into v_order_id;

  for v_item in
    select
      (item.value ->> 'product_id')::uuid as product_id,
      sum((item.value ->> 'quantity')::integer)::integer as quantity
    from jsonb_array_elements(p_items) as item(value)
    group by (item.value ->> 'product_id')::uuid
    order by (item.value ->> 'product_id')::uuid
  loop
    select product.name, product.price
      into v_product_name, v_unit_price
    from public.products as product
    where product.id = v_item.product_id;

    insert into public.order_items (
      order_id,
      product_id,
      product_name,
      unit_price,
      quantity
    ) values (
      v_order_id,
      v_item.product_id,
      v_product_name,
      v_unit_price,
      v_item.quantity
    );
  end loop;

  return v_order_id;
end;
$$;

drop function if exists public.place_order_with_stock(
  text, text, text, text, text, text, text, text, text, jsonb
);

revoke all on function public.place_order_with_stock(
  text, text, text, text, text, text, text, text, text, jsonb, text
) from public;
grant execute on function public.place_order_with_stock(
  text, text, text, text, text, text, text, text, text, jsonb, text
) to authenticated;

create or replace function public.cancel_cod_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
  v_payment_method text;
  v_status text;
  v_item record;
begin
  if auth.uid() is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  if p_order_id is null then
    raise exception 'ORDER_ID_REQUIRED';
  end if;

  select customer_id, payment_method, status
    into v_customer_id, v_payment_method, v_status
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'ORDER_NOT_FOUND';
  end if;
  if v_customer_id is distinct from auth.uid() then
    raise exception 'ORDER_ACCESS_DENIED';
  end if;
  if lower(coalesce(v_payment_method, '')) <> 'cod' then
    raise exception 'ONLY_COD_ORDERS_CAN_BE_CANCELLED';
  end if;
  if lower(coalesce(v_status, '')) <> 'pending' then
    raise exception 'ORDER_CANNOT_BE_CANCELLED_AFTER_PROCESSING';
  end if;

  for v_item in
    select product_id, sum(quantity)::integer as quantity
    from public.order_items
    where order_id = p_order_id
      and product_id is not null
    group by product_id
    order by product_id
  loop
    update public.products
    set stock_quantity = stock_quantity + v_item.quantity
    where id = v_item.product_id;
  end loop;

  update public.orders
  set status = 'cancelled', updated_at = now()
  where id = p_order_id;
end;
$$;

revoke all on function public.cancel_cod_order(uuid) from public;
grant execute on function public.cancel_cod_order(uuid) to authenticated;

commit;