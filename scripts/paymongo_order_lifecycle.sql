begin;

alter table public.orders
  add column if not exists checkout_request_id text,
  add column if not exists paymongo_checkout_session_id text,
  add column if not exists paymongo_checkout_idempotency_key uuid,
  add column if not exists paymongo_checkout_lock_until timestamptz,
  add column if not exists paymongo_checkout_created_at timestamptz,
  add column if not exists payment_review_required boolean not null default false;

create unique index if not exists orders_customer_checkout_request_id_key
  on public.orders (customer_id, checkout_request_id)
  where checkout_request_id is not null;

create unique index if not exists orders_paymongo_checkout_session_id_key
  on public.orders (paymongo_checkout_session_id)
  where paymongo_checkout_session_id is not null;

create index if not exists orders_pending_paymongo_expiry_idx
  on public.orders (paymongo_checkout_created_at)
  where payment_method = 'paymongo'
    and payment_status = 'unpaid'
    and status = 'pending';

create or replace function public.begin_paymongo_checkout(p_order_id uuid)
returns table (result_code text, session_id text, request_key uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_payment_method text;
  v_payment_status text;
  v_order_status text;
  v_session_id text;
  v_request_key uuid;
  v_lock_until timestamptz;
begin
  select
    orders.payment_method,
    orders.payment_status,
    orders.status,
    orders.paymongo_checkout_session_id,
    orders.paymongo_checkout_idempotency_key,
    orders.paymongo_checkout_lock_until
  into
    v_payment_method,
    v_payment_status,
    v_order_status,
    v_session_id,
    v_request_key,
    v_lock_until
  from public.orders as orders
  where orders.id = p_order_id
  for update;

  if not found
     or v_payment_method <> 'paymongo'
     or v_payment_status <> 'unpaid'
     or v_order_status <> 'pending' then
    return query select 'not_payable'::text, null::text, null::uuid;
    return;
  end if;

  if v_lock_until > now() then
    return query select 'busy'::text, null::text, null::uuid;
    return;
  end if;

  if v_session_id is not null then
    return query select 'existing'::text, v_session_id, v_request_key;
    return;
  end if;

  v_request_key := coalesce(v_request_key, gen_random_uuid());
  update public.orders as orders
  set paymongo_checkout_idempotency_key = v_request_key,
      paymongo_checkout_lock_until = now() + interval '2 minutes'
  where orders.id = p_order_id;

  return query select 'create'::text, null::text, v_request_key;
end;
$$;

create or replace function public.save_paymongo_checkout_session(
  p_order_id uuid,
  p_request_key uuid,
  p_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders as orders
  set paymongo_checkout_session_id = p_session_id,
      paymongo_checkout_created_at = now(),
      paymongo_checkout_lock_until = null
  where orders.id = p_order_id
    and orders.payment_method = 'paymongo'
    and orders.payment_status = 'unpaid'
    and orders.status = 'pending'
    and orders.paymongo_checkout_session_id is null
    and orders.paymongo_checkout_idempotency_key = p_request_key;

  return found;
end;
$$;

create or replace function public.release_paymongo_checkout_lock(
  p_order_id uuid,
  p_request_key uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.orders as orders
  set paymongo_checkout_lock_until = null
  where orders.id = p_order_id
    and orders.payment_status = 'unpaid'
    and orders.paymongo_checkout_session_id is null
    and (p_request_key is null or orders.paymongo_checkout_idempotency_key = p_request_key);
end;
$$;

create or replace function public.claim_paymongo_checkout_expiry(
  p_order_id uuid,
  p_session_id text,
  p_before timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lock_until timestamptz;
begin
  select orders.paymongo_checkout_lock_until
    into v_lock_until
  from public.orders as orders
  where orders.id = p_order_id
    and orders.payment_method = 'paymongo'
    and orders.payment_status = 'unpaid'
    and orders.status = 'pending'
    and orders.paymongo_checkout_session_id = p_session_id
    and orders.paymongo_checkout_created_at <= p_before
  for update;

  if not found or v_lock_until > now() then
    return false;
  end if;

  update public.orders as orders
  set paymongo_checkout_lock_until = now() + interval '2 minutes'
  where orders.id = p_order_id;

  return true;
end;
$$;

create or replace function public.expire_paymongo_order(
  p_order_id uuid,
  p_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item record;
begin
  perform 1
  from public.orders as orders
  where orders.id = p_order_id
    and orders.payment_method = 'paymongo'
    and orders.payment_status = 'unpaid'
    and orders.status = 'pending'
    and orders.paymongo_checkout_session_id = p_session_id
  for update;

  if not found then
    return false;
  end if;

  for v_item in
    select items.product_id, sum(items.quantity)::integer as quantity
    from public.order_items as items
    where items.order_id = p_order_id
      and items.product_id is not null
    group by items.product_id
    order by items.product_id
  loop
    update public.products as products
    set stock_quantity = products.stock_quantity + v_item.quantity
    where products.id = v_item.product_id;
  end loop;

  update public.orders as orders
  set status = 'cancelled',
      payment_status = 'expired',
      paymongo_checkout_lock_until = null,
      updated_at = now()
  where orders.id = p_order_id;

  return true;
end;
$$;

create or replace function public.record_paymongo_payment(
  p_order_id uuid,
  p_session_id text,
  p_amount bigint,
  p_currency text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
begin
  select orders.*
    into v_order
  from public.orders as orders
  where orders.id = p_order_id
  for update;

  if not found or v_order.payment_method <> 'paymongo' then
    return 'not_paymongo_order';
  end if;
  if v_order.paymongo_checkout_session_id is null then
    raise exception 'PAYMONGO_SESSION_NOT_SAVED';
  end if;
  if v_order.paymongo_checkout_session_id <> p_session_id then
    return 'session_mismatch';
  end if;
    if p_currency is distinct from 'PHP'
      or p_amount is distinct from round(v_order.total * 100)::bigint then
    raise exception 'PAYMONGO_AMOUNT_MISMATCH';
  end if;
  if v_order.payment_status = 'paid' then
    return case when v_order.payment_review_required then 'late_payment_review' else 'already_paid' end;
  end if;
  if v_order.payment_status = 'expired' or v_order.status = 'cancelled' then
    update public.orders as orders
    set payment_status = 'paid',
        payment_review_required = true,
        updated_at = now()
    where orders.id = p_order_id;
    return 'late_payment_review';
  end if;
  if v_order.payment_status <> 'unpaid' then
    return 'ignored';
  end if;

  update public.orders as orders
  set payment_status = 'paid',
      updated_at = now()
  where orders.id = p_order_id;

  return 'paid';
end;
$$;

revoke all on function public.begin_paymongo_checkout(uuid) from public, anon, authenticated;
revoke all on function public.save_paymongo_checkout_session(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.release_paymongo_checkout_lock(uuid, uuid) from public, anon, authenticated;
revoke all on function public.claim_paymongo_checkout_expiry(uuid, text, timestamptz) from public, anon, authenticated;
revoke all on function public.expire_paymongo_order(uuid, text) from public, anon, authenticated;
revoke all on function public.record_paymongo_payment(uuid, text, bigint, text) from public, anon, authenticated;

grant execute on function public.begin_paymongo_checkout(uuid) to service_role;
grant execute on function public.save_paymongo_checkout_session(uuid, uuid, text) to service_role;
grant execute on function public.release_paymongo_checkout_lock(uuid, uuid) to service_role;
grant execute on function public.claim_paymongo_checkout_expiry(uuid, text, timestamptz) to service_role;
grant execute on function public.expire_paymongo_order(uuid, text) to service_role;
grant execute on function public.record_paymongo_payment(uuid, text, bigint, text) to service_role;

commit;