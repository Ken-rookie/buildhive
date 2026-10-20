create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select cron.unschedule(jobid)
from cron.job
where jobname = 'expire-paymongo-checkouts';

select cron.schedule(
  'expire-paymongo-checkouts',
  '*/5 * * * *',
  $$
    select net.http_post(
      url := (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'buildhive_supabase_url'
      ) || '/functions/v1/expire-paymongo-checkouts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'buildhive_supabase_publishable_key'
        ),
        'x-paymongo-cleanup-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'buildhive_paymongo_cleanup_secret'
        )
      ),
      body := '{}'::jsonb
    );
  $$
);