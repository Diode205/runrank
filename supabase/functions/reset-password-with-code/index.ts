// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeUka(value: string) {
  return value.trim().toUpperCase().replace(/[\s-]+/g, "");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        { error: "Missing Supabase environment configuration" },
        500,
      );
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const { ukaNumber, resetCode, newPassword } = await req.json();

    if (
      typeof ukaNumber !== "string" ||
      typeof resetCode !== "string" ||
      typeof newPassword !== "string"
    ) {
      return jsonResponse({ error: "Invalid request body" }, 400);
    }

    const normalizedUka = normalizeUka(ukaNumber);
    const normalizedCode = resetCode.trim().toUpperCase();

    if (normalizedUka.length === 0 || normalizedCode.length === 0) {
      return jsonResponse({ error: "UKA number and reset code are required" }, 400);
    }

    if (newPassword.trim().length < 8) {
      return jsonResponse(
        { error: "Password must be at least 8 characters long" },
        400,
      );
    }

    const { data: codeRow, error: codeError } = await adminClient
      .from("password_reset_codes")
      .select("id, user_id, status, expires_at")
      .eq("reset_code", normalizedCode)
      .maybeSingle();

    if (codeError) {
      console.error("Failed to load reset code", codeError);
      return jsonResponse({ error: "Could not verify reset code" }, 500);
    }

    if (!codeRow) {
      return jsonResponse({ error: "Invalid reset code" }, 400);
    }

    if (codeRow.status !== "issued") {
      return jsonResponse({ error: "This reset code has already been used" }, 400);
    }

    if (new Date(codeRow.expires_at).getTime() < Date.now()) {
      return jsonResponse({ error: "This reset code has expired" }, 400);
    }

    const { data: profileRows, error: profileError } = await adminClient
      .from("user_profiles")
      .select("id, uka_number")
      .eq("id", codeRow.user_id);

    if (profileError) {
      console.error("Failed to load user profile", profileError);
      return jsonResponse({ error: "Could not verify member details" }, 500);
    }

    const matchingProfile = (profileRows ?? []).find((row) => {
      const currentUka = typeof row.uka_number === "string"
        ? normalizeUka(row.uka_number)
        : "";
      return currentUka === normalizedUka;
    });

    if (!matchingProfile) {
      return jsonResponse(
        { error: "UKA number and reset code do not match" },
        400,
      );
    }

    const { error: updateAuthError } = await adminClient.auth.admin.updateUserById(
      codeRow.user_id,
      { password: newPassword.trim() },
    );

    if (updateAuthError) {
      console.error("Failed to update password", updateAuthError);
      return jsonResponse({ error: "Could not update password" }, 500);
    }

    const { error: markUsedError } = await adminClient
      .from("password_reset_codes")
      .update({
        status: "used",
        used_at: new Date().toISOString(),
      })
      .eq("id", codeRow.id);

    if (markUsedError) {
      console.error("Failed to mark reset code used", markUsedError);
      return jsonResponse(
        { error: "Password changed, but reset code status could not be updated" },
        500,
      );
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error("reset-password-with-code error", error);
    return jsonResponse({ error: `Server error: ${error}` }, 500);
  }
});
