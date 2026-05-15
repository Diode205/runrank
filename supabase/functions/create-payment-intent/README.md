# Stripe Payment Edge Function

Supabase Edge Function to create Stripe PaymentIntents for RunRank membership purchases.

## Deploy

1. Set your Stripe secret key. The function supports a safe fallback key plus
   optional per-club keys:
   ```
   supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx --project-ref yzccwmhgqlgguighfhsk
   ```

   Optional:
   ```
   supabase secrets set CLUB_STRIPE_SECRET_KEY=sk_live_default_club_xxx --project-ref yzccwmhgqlgguighfhsk
   supabase secrets set STRIPE_SECRET_KEY_NORWICH_ROAD_RUNNERS=sk_live_nrr_xxx --project-ref yzccwmhgqlgguighfhsk
   supabase secrets set STRIPE_SECRET_KEY_NNBR_NORTH_NORFOLK_BEACH_RUNNERS=sk_live_nnbr_xxx --project-ref yzccwmhgqlgguighfhsk
   supabase secrets set PLATFORM_STRIPE_SECRET_KEY=sk_live_platform_xxx --project-ref yzccwmhgqlgguighfhsk
   ```

   Club-specific secrets are selected from `metadata.club`. For example
   `Norwich Road Runners` maps to
   `STRIPE_SECRET_KEY_NORWICH_ROAD_RUNNERS`. If no club-specific key exists,
   the function falls back to `CLUB_STRIPE_SECRET_KEY`, then
   `STRIPE_SECRET_KEY`.

2. Deploy the function:
   ```
   supabase functions deploy create-payment-intent --project-ref yzccwmhgqlgguighfhsk
   ```

3. Your endpoint URL:
   ```
   https://yzccwmhgqlgguighfhsk.functions.supabase.co/create-payment-intent
   ```

## Test Locally

Start local function:
```
supabase functions serve create-payment-intent --env-file ./supabase/.env.local
```

Test with curl:
```
curl -X POST http://localhost:54321/functions/v1/create-payment-intent \
  -H 'content-type: application/json' \
  -d '{"amount":3000,"currency":"gbp","tier":"1st Claim","metadata":{"test":"ok","club":"Norwich Road Runners","payment_flow":"club"}}'
```

## Test Deployed

```
curl -X POST https://yzccwmhgqlgguighfhsk.functions.supabase.co/create-payment-intent \
  -H 'content-type: application/json' \
  -d '{"amount":3000,"currency":"gbp","tier":"1st Claim","metadata":{"test":"ok","club":"Norwich Road Runners","payment_flow":"club"}}'
```

Expected response:
```json
{
  "paymentIntentClientSecret": "pi_..._secret_..."
}
```
