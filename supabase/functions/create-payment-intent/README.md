# Stripe Payment Edge Function

Supabase Edge Function to create Stripe PaymentIntents for RunRank membership purchases.

## Deploy

1. Set your Stripe secret key:
   ```
   supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx --project-ref yzccwmhgqlgguighfhsk
   ```

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
  -d '{"amount":3000,"currency":"gbp","tier":"1st Claim","metadata":{"test":"ok"}}'
```

## Test Deployed

```
curl -X POST https://yzccwmhgqlgguighfhsk.functions.supabase.co/create-payment-intent \
  -H 'content-type: application/json' \
  -d '{"amount":3000,"currency":"gbp","tier":"1st Claim","metadata":{"test":"ok"}}'
```

Expected response:
```json
{
  "paymentIntentClientSecret": "pi_..._secret_..."
}
```
