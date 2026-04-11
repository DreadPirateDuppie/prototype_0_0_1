# Pushinn

A skate-spot discovery and battle app built with Flutter.

## About

Pushinn lets skaters discover spots near them, upload clips, and challenge each other in timed trick battles. Features include:

- **Spot Map** – find and share skateboarding spots using an interactive map
- **VS Battles** – challenge other skaters to trick duels with wager-based outcomes
- **Feed** – follow other skaters and stay up to date with their latest posts
- **Leaderboards** – compete for the top spot in global and local rankings
- **Admin Dashboard** – moderation tools for managing users, posts, and reports

## Getting Started

Copy `.env.example` to `.env` and fill in your Supabase URL and anon key before running.

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Then run:

```bash
flutter pub get
flutter run
```

## Building for Release

### Android
```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```
