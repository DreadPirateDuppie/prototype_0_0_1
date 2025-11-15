# Supabase Flutter App

A Flutter application with Supabase integration for authentication and data storage.

## Features

- User authentication (sign in/sign up)
- Light/dark theme support
- Error handling
- Environment-based configuration

## Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- Supabase account and project

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
4. Update `.env` with your Supabase credentials:
   ```env
   SUPABASE_URL=your_supabase_url_here
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   ```
5. Run the app:
   ```bash
   flutter run
   ```

## Environment Variables

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anon/public key

## Security

- Never commit your `.env` file
- Add `.env` to your `.gitignore`
- Use Row Level Security (RLS) in Supabase
- Follow the principle of least privilege for database access

## Development

### Code Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter format .` to format your code
- Use meaningful commit messages

### Testing

Run tests with:
```bash
flutter test
```
