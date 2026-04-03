# Sync Strategy

## Current approach
- The app remains local-first. Drift is always the source of truth for the running device.
- Supabase is optional. If `SUPABASE_URL` or `SUPABASE_ANON_KEY` is missing, the app keeps working locally and does not crash.
- The first remote layer syncs one JSON snapshot per root entity instead of mirroring every local child table independently.

## Root entities in scope
- `clients`
- `orders`
- `products`
- `ingredients`
- `recipes`
- `packaging`
- `suppliers`
- `monthly_plans`
- `finance_manual_entries`

Child rows such as order items, production plans, recipe items, supplier prices, and monthly occurrences travel inside the root snapshot payload.

## Local sync queue
- Every local write marks the root row as `pending`.
- The queue is deduplicated by `entity_type + entity_id`, so repeated edits keep only the latest pending intent.
- Cross-module effects also enqueue the correct root entity:
  - production updates queue `orders`, `ingredients`, and `packaging`
  - purchases queue `ingredients` or `packaging`
  - receivable settlement queues `orders`
  - supplier price registration queues `suppliers`
  - monthly draft generation queues `monthly_plans`

## Push and pull flow
1. Read pending local queue rows.
2. Build the latest root snapshot from Drift.
3. Upsert the snapshot into Supabase table `sync_entity_snapshots`.
4. Mark the local root as `synced` when the upload succeeds.
5. Pull remote snapshots newer than the last successful pull timestamp.
6. Apply newer remote snapshots back into Drift, replacing the root children included in the payload.

## Conflict strategy
- Current rule: last-write-wins by root `updatedAt`.
- If the remote snapshot is newer than the local root row, the remote snapshot replaces the local root and its child rows.
- If the local root row is newer or equal, the local version wins and the remote snapshot is skipped.
- This strategy is intentionally simple for the first real offline-first block and is exposed in code and docs instead of hidden behind implicit behavior.

## Deletions
- Root tables already have a `deletedAt` field ready for soft delete propagation.
- This block focuses on create and update synchronization.
- Remote delete handling is intentionally left as an extension point for a later block with stronger auth and team rules.

## Team readiness
- The local database now seeds one default team and one current-device member.
- Team role support is intentionally minimal for now: `owner` and `employee`.
- The remote SQL also includes `app_teams` and `app_team_members` so future auth-backed collaboration can reuse the same structure.

## Security note
- The SQL baseline for block 15 uses temporary permissive policies because authentication is still out of scope.
- Before production, replace those policies with membership-aware rules based on `auth.uid()` and `app_team_members.auth_user_id`.
