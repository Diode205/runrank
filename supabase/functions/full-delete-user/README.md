# full-delete-user

Supabase Edge Function used by the admin team page to permanently remove a member after soft removal.

What it does:
- Verifies the caller is an admin.
- Restricts deletion to members in the same club.
- Removes the auth account.
- Deletes the `user_profiles` row.
- Deletes personal interaction data such as notifications, comments, reactions, event responses, host messages, race results, and migration rows.
- Clears committee assignments.
- Anonymises club history that may need to remain visible, such as club posts and club records.
- Returns a JSON payload including whether the profile row is confirmed deleted.

Required environment variables:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` or `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

Deploy:

```bash
supabase functions deploy full-delete-user
```

Local serve:

```bash
supabase functions serve full-delete-user --env-file supabase/.env
```

Notes:
- The Flutter client calls this function from `AdminTeamPage` and now verifies the profile row is really gone before showing a success state.
- If your production project already has a `full-delete-user` function deployed elsewhere, compare it with this implementation before replacing it.