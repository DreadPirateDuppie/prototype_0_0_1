## App Overview
- Uses `provider` for state (`ThemeProvider`, `ErrorProvider`) and `supabase_flutter` for backend auth/data.
- Main navigation is a tabbed `HomeScreen` with `Map`, `Feed`, `Profile`, `Rewards`, `Settings`; plus admin dashboards.
- Error overlay and basic connectivity banner exist; image upload/compress flows are implemented; posts model `MapPost` backs feed/map.

## Strengths
- Clear separation into screens/tabs/services/models; Supabase calls centralized in `SupabaseService`.
- Consistent UI patterns (dialogs, bottom sheets, banners) and Material 3 theming handled by `ThemeProvider`.
- Pragmatic error overlay via `ErrorProvider` and a dedicated `ErrorService` for logging.
- Rewards and points flow is sketched with `UserPoints` and spin UI, and admin tools provide basic analytics.

## Issues Found
- Connectivity banner never updates because `ConnectivityService.initialize()` is not called anywhere. Reference: `lib/services/connectivity_service.dart` exists but no init invocation in `lib/main.dart:10-52`.
- Error logging is defined but not activated; `ErrorService.initialize()` is never called. Reference: `lib/services/error_service.dart`.
- Points update overwrites instead of incrementing. Reference: `lib/services/supabase_service.dart:383-399` (comment notes this); should add to existing points rather than set.
- `MapPost.fromMap` casts numeric fields directly to `double` and may throw if backend returns `int`. Reference: `lib/models/post.dart:58-59`; should use `(map['latitude'] as num).toDouble()` and same for longitude.
- Frequent full reloads of posts (e.g., after like/rate/edit) are inefficient; consider local state updates or pagination for `FeedTab`. Reference: `lib/tabs/feed_tab.dart:23-30, 66-72`.
- Marker list rebuilds entirely on each refresh; for larger datasets consider clustering or incremental updates. Reference: `lib/tabs/map_tab.dart:38-66, 158-193`.
- Two admin UIs (`AdminDashboard` and `AdminDashboardScreen`) overlap; consolidate to one to avoid duplication.
- Minor UX: sample markers include mislabeled coordinates; non-blocking.

## Proposed Changes
1. Initialize services in `main()`
   - Call `ConnectivityService.initialize()` and `ErrorService.initialize()` before `runApp`. Reference: `lib/main.dart:10-52`.
   - Ensure `ConnectivityService.dispose()` is called on app shutdown via a `WidgetsBindingObserver` in `MyApp` if desired.
2. Fix points increment logic
   - Read current points then write `points + pointsWon`, keeping `last_spin_date`. Reference: `lib/services/supabase_service.dart:378-399`.
   - Optionally add a Postgres function (RPC) for atomic increment; for now, do a read-then-update.
3. Harden `MapPost.fromMap` numeric parsing
   - Change direct `double` casts to `num.toDouble()` for `latitude` and `longitude`. Reference: `lib/models/post.dart:58-59`.
4. Feed pagination or targeted refresh
   - Introduce basic pagination using `PaginatedList` utility. Reference: `lib/utils/paginated_list.dart`.
   - Or update the liked post inline without re-fetching all posts in `FeedTab`. Reference: `lib/tabs/feed_tab.dart:23-30`.
5. Map marker performance
   - Defer clustering for now; at minimum, avoid clearing/re-adding all markers when adding a single post. Reference: `lib/tabs/map_tab.dart:44-61`.
6. Admin consolidation
   - Choose `AdminDashboard` as the primary screen and remove/redirect `AdminDashboardScreen`, or vice versa; unify analytics and user management to a single place. References: `lib/screens/admin_dashboard.dart`, `lib/screens/admin_dashboard_screen.dart`.

## Validation Plan
- Run on emulator; verify:
  - Offline banner toggles correctly when Wi‑Fi is disabled/enabled (`HomeScreen` shows `ConnectivityService.buildOfflineBanner`).
  - Error logging creates rows in `error_logs` on a forced error and doesn’t loop (`ErrorService`).
  - Wheel spin increments points rather than resets; last spin date updates (`RewardsTab`, `UserPoints.canSpinToday`).
  - Map posts load when numeric fields are ints; feed and map render without type errors.

## Implementation Steps
- Edit `lib/main.dart` to initialize connectivity and error services.
- Edit `lib/services/supabase_service.dart` to increment points and keep last spin date.
- Edit `lib/models/post.dart` to use `num.toDouble()` for lat/lng.
- Optionally optimize `FeedTab` post refresh and `MapTab` marker updates.

## Request
- Confirm this plan and which optional items (pagination, clustering, admin consolidation) you want included now. On approval, I’ll implement the core fixes first, then proceed with chosen enhancements.