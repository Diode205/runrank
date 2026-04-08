// @ts-nocheck
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DELETED_MEMBER_NAME = "Deleted member";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function extractAvatarPath(publicUrl: string | null | undefined) {
  if (!publicUrl) return null;

  const marker = "/storage/v1/object/public/avatars/";
  const idx = publicUrl.indexOf(marker);
  if (idx < 0) return null;

  const path = publicUrl.slice(idx + marker.length);
  return path ? decodeURIComponent(path) : null;
}

function isMissingResourceError(error: { code?: string; message?: string } | null) {
  if (!error) return false;

  return (
    error.code === "42P01" ||
    error.code === "PGRST205" ||
    error.message?.toLowerCase().includes("does not exist") === true ||
    error.message?.toLowerCase().includes("could not find") === true
  );
}

function isConstraintError(error: { code?: string; message?: string } | null) {
  if (!error) return false;

  return error.code === "23502" || error.code === "23503";
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
    const anonKey =
      Deno.env.get("SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      return jsonResponse(
        { error: "Missing Supabase environment configuration" },
        500,
      );
    }

    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    const {
      data: { user: callerUser },
      error: callerAuthError,
    } = await callerClient.auth.getUser();

    if (callerAuthError || !callerUser) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { userId } = await req.json();
    if (typeof userId !== "string" || userId.trim().length === 0) {
      return jsonResponse({ error: "Invalid userId" }, 400);
    }

    if (userId === callerUser.id) {
      return jsonResponse(
        { error: "Admins cannot full-delete their own account here" },
        400,
      );
    }

    const { data: callerProfile, error: callerProfileError } = await adminClient
      .from("user_profiles")
      .select("id, is_admin, club")
      .eq("id", callerUser.id)
      .maybeSingle();

    if (callerProfileError) {
      console.error("Failed to load caller profile", callerProfileError);
      return jsonResponse({ error: "Could not verify admin access" }, 500);
    }

    if (!callerProfile || callerProfile.is_admin !== true) {
      return jsonResponse({ error: "Admin access required" }, 403);
    }

    const { data: targetProfile, error: targetProfileError } = await adminClient
      .from("user_profiles")
      .select("id, club, full_name, avatar_url")
      .eq("id", userId)
      .maybeSingle();

    if (targetProfileError) {
      console.error("Failed to load target profile", targetProfileError);
      return jsonResponse({ error: "Could not load target profile" }, 500);
    }

    if (!targetProfile) {
      return jsonResponse({ deleted: true, alreadyMissing: true });
    }

    if (
      callerProfile.club &&
      targetProfile.club &&
      callerProfile.club !== targetProfile.club
    ) {
      return jsonResponse(
        { error: "You can only delete members from your own club" },
        403,
      );
    }

    const summary: Record<string, string> = {};

    const safeDelete = async (table: string, column: string) => {
      const { error } = await adminClient.from(table).delete().eq(column, userId);
      if (error) {
        if (isMissingResourceError(error)) {
          summary[table] = "not present";
          return;
        }
        console.error(`Delete failed for ${table}.${column}`, error);
        throw new Error(`Failed deleting ${table}`);
      }
      summary[table] = "deleted";
    };

    const safeUpdate = async (
      table: string,
      values: Record<string, unknown>,
      column: string,
    ) => {
      const { error } = await adminClient.from(table).update(values).eq(column, userId);
      if (error) {
        if (isMissingResourceError(error)) {
          summary[table] = "not present";
          return;
        }
        console.error(`Update failed for ${table}.${column}`, error);
        throw new Error(`Failed updating ${table}`);
      }
      summary[table] = "anonymised";
    };

    const deleteAuthoredPosts = async () => {
      const { data: posts, error: postsError } = await adminClient
        .from("club_posts")
        .select("id")
        .eq("author_id", userId);

      if (postsError) {
        if (isMissingResourceError(postsError)) {
          summary.club_posts = "not present";
          return;
        }
        console.error("Failed loading authored posts", postsError);
        throw new Error("Failed loading authored posts");
      }

      const postIds = (posts ?? [])
        .map((row) => row.id as string | null)
        .filter((id): id is string => Boolean(id));

      if (postIds.length === 0) {
        summary.club_posts = "no authored posts";
        return;
      }

      const childTables = [
        "club_post_attachments",
        "club_post_reactions",
        "club_post_comments",
      ];

      for (const table of childTables) {
        const { error } = await adminClient
          .from(table)
          .delete()
          .in("post_id", postIds);
        if (error && !isMissingResourceError(error)) {
          console.error(`Failed deleting ${table} for authored posts`, error);
          throw new Error(`Failed deleting ${table}`);
        }
      }

      const { error: deletePostsError } = await adminClient
        .from("club_posts")
        .delete()
        .in("id", postIds);
      if (deletePostsError) {
        console.error("Failed deleting authored posts", deletePostsError);
        throw new Error("Failed deleting club posts");
      }

      summary.club_posts = "deleted authored posts";
    };

    const avatarPath = extractAvatarPath(targetProfile.avatar_url);
    if (avatarPath) {
      const { error } = await adminClient.storage.from("avatars").remove([
        avatarPath,
      ]);
      if (error) {
        console.warn("Avatar removal failed", error);
      } else {
        summary.avatars = "removed";
      }
    }

    await safeDelete("notifications", "user_id");
    await safeDelete("membership_migrations", "user_id");
    await safeDelete("club_post_reactions", "user_id");
    await safeDelete("club_post_comments", "user_id");
    await safeDelete("event_comments", "user_id");
    await safeDelete("event_comment_reactions", "user_id");
    await safeDelete("club_event_responses", "user_id");
    await safeDelete("race_results", "user_id");

    const { error: deleteSenderMessagesError } = await adminClient
      .from("event_host_messages")
      .delete()
      .eq("sender_id", userId);
    if (deleteSenderMessagesError) {
      if (isMissingResourceError(deleteSenderMessagesError)) {
        summary.event_host_messages = "not present";
      } else {
      console.error("Delete failed for event_host_messages.sender_id", deleteSenderMessagesError);
      throw new Error("Failed deleting event host messages");
      }
    }

    if (summary.event_host_messages != "not present") {
      const { error: deleteReceiverMessagesError } = await adminClient
        .from("event_host_messages")
        .delete()
        .eq("receiver_id", userId);
      if (deleteReceiverMessagesError) {
        if (isMissingResourceError(deleteReceiverMessagesError)) {
          summary.event_host_messages = "not present";
        } else {
          console.error("Delete failed for event_host_messages.receiver_id", deleteReceiverMessagesError);
          throw new Error("Failed deleting event host messages");
        }
      }
      if (summary.event_host_messages != "not present") {
        summary.event_host_messages = "deleted";
      }
    }

    const { error: committeeRolesError } = await adminClient
      .from("committee_roles")
      .update({
        user_id: null,
        name: null,
        email: null,
        avatar_url: null,
      })
      .eq("user_id", userId);
    if (committeeRolesError) {
      if (isMissingResourceError(committeeRolesError)) {
        summary.committee_roles = "not present";
      } else {
        console.error("Update failed for committee_roles", committeeRolesError);
        throw new Error("Failed updating committee roles");
      }
    } else {
      summary.committee_roles = "cleared";
    }

    await deleteAuthoredPosts();

    await safeUpdate(
      "club_records",
      {
        runner_name: DELETED_MEMBER_NAME,
      },
      "user_id",
    );

    const { error: clearClubRecordUserError } = await adminClient
      .from("club_records")
      .update({ user_id: null })
      .eq("user_id", userId);
    if (clearClubRecordUserError) {
      if (isConstraintError(clearClubRecordUserError)) {
        const { error: deleteClubRecordsError } = await adminClient
          .from("club_records")
          .delete()
          .eq("user_id", userId);
        if (deleteClubRecordsError) {
          console.error("Failed deleting club_records after null fallback failed", deleteClubRecordsError);
          throw new Error("Failed deleting club records");
        }
        summary.club_records = "deleted";
      } else {
        console.warn("Could not null club_records.user_id", clearClubRecordUserError);
      }
    }

    const { error: clearCreatedEventsError } = await adminClient
      .from("club_events")
      .update({ created_by: null })
      .eq("created_by", userId);
    if (clearCreatedEventsError) {
      if (!isMissingResourceError(clearCreatedEventsError)) {
        console.warn("Could not null club_events.created_by", clearCreatedEventsError);
      }
    } else {
      summary.club_events = "creator cleared";
    }

    const { error: clearHostUserError } = await adminClient
      .from("club_events")
      .update({ host_user_id: null })
      .eq("host_user_id", userId);
    if (clearHostUserError) {
      if (!isMissingResourceError(clearHostUserError)) {
        console.warn("Could not null club_events.host_user_id", clearHostUserError);
      }
    } else {
      summary.club_events = summary.club_events
        ? `${summary.club_events}, host cleared`
        : "host cleared";
    }

    const { error: deleteProfileError } = await adminClient
      .from("user_profiles")
      .delete()
      .eq("id", userId);
    if (deleteProfileError) {
      console.error("Delete failed for user_profiles", deleteProfileError);
      throw new Error("Failed deleting user profile");
    }
    summary.user_profiles = "deleted";

    const { error: deleteAuthUserError } = await adminClient.auth.admin.deleteUser(
      userId,
    );
    if (deleteAuthUserError) {
      console.error("Failed deleting auth user", deleteAuthUserError);
      throw new Error("Failed deleting auth account");
    }
    summary.auth = "deleted";

    const { data: remainingProfile, error: verifyProfileError } = await adminClient
      .from("user_profiles")
      .select("id")
      .eq("id", userId)
      .maybeSingle();
    if (verifyProfileError) {
      console.error("Failed verifying profile deletion", verifyProfileError);
      throw new Error("Failed verifying profile deletion");
    }

    return jsonResponse({
      deleted: remainingProfile == null,
      userId,
      fullName: targetProfile.full_name,
      summary,
    });
  } catch (error) {
    console.error("full-delete-user failed", error);
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : "Unknown error",
      },
      500,
    );
  }
});