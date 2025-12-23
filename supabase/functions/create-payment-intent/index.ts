// Supabase Edge Function: create-payment-intent
// Deno runtime for Stripe PaymentIntent creation

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { amount, currency = "gbp", tier, metadata } = await req.json();
    if (!amount || typeof amount !== "number") {
      return new Response(JSON.stringify({ error: "Invalid amount" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeKey) {
      return new Response(JSON.stringify({ error: "Missing STRIPE_SECRET_KEY" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const stripeBase = "https://api.stripe.com/v1";

    // Create a PaymentIntent
    const piParams = new URLSearchParams();
    piParams.set("amount", String(amount));
    piParams.set("currency", currency);
    piParams.set("automatic_payment_methods[enabled]", "true");
    if (tier) piParams.set("description", `RunRank membership: ${tier}`);

    // Add metadata
    if (metadata && typeof metadata === "object") {
      for (const [k, v] of Object.entries(metadata)) {
        if (v !== undefined && v !== null) {
          piParams.set(`metadata[${k}]`, String(v));
        }
      }
    }

    const piResp = await fetch(`${stripeBase}/payment_intents`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: piParams.toString(),
    });

    const pi = await piResp.json();
    if (!piResp.ok) {
      console.error("Stripe error:", pi);
      return new Response(JSON.stringify({ error: "Stripe API error", details: pi }), {
        status: piResp.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Return client secret
    return new Response(
      JSON.stringify({
        paymentIntentClientSecret: pi.client_secret,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("Server error:", e);
    return new Response(JSON.stringify({ error: `Server error: ${e}` }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
