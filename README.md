# MSU Well-being

A non-clinical mental well-being companion app for jamaah and civitas
akademika of Masjid Syamsul 'Ulum (MSU), Telkom University. It is the
follow-up channel for the MSU web-based well-being assessment.

Users can view their assessment reports, do a daily mood check-in, talk to an
AI companion, contact an MSU psychologist via WhatsApp, learn through short
reviewed materials and relaxing exercises, reach crisis help from anywhere,
and control their privacy and consent.

This repository contains the **Flutter frontend only**. The backend API,
chatbot logic, and psychologist panel are built separately. The app has no
mock data: rapor, check-in, chat, and config come from the backend, while
articles, sounds, and exercises ship with the app.

The full specification is in [CLAUDE.md](CLAUDE.md).

## Screenshots

_Coming soon._

## Requirements

- Flutter 3.47.7+ (stable channel), Dart 3.13+
- Android SDK (min API 24, compile/target API 36), or Xcode for iOS builds
- An Android emulator or device for running the app

## Setup (about 5 minutes)

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build -d
```

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/generated/`) are not
committed; CI generates them too. Re-run the last two commands after changing
models, providers, or `lib/l10n/app_id.arb`.

## Run

```sh
flutter run --dart-define=API_BASE_URL=https://<backend-host>
```

| Key | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `https://api.example.invalid` | Backend base URL (HTTPS required outside `dev`) |
| `APP_ENV` | `dev` | `dev` / `staging` / `prod` (verbose logs off in `prod`) |
| `DEMO_LOGIN` | `true` | Enables the five demo accounts (must be `false` in `prod`) |

Never commit real URLs, keys, or phone numbers.

### Where the data comes from

| Feature | Source |
|---|---|
| Rapor, check-in, Asisten AI chat, config (WhatsApp, help lines) | Backend API. The expected endpoints and JSON are documented on each remote source in `lib/features/*/data/sources/`. |
| Materi (10 articles), Suara tenang, exercises, garden | Bundled in the app (no backend needed) |
| Crisis help lines | Backend `/config`, falling back to verified national lines (Healing119, 112, 118) |

Without a backend, the backend features show their calm error state with
*Coba lagi*; everything else works.

### Demo accounts

Five accounts sign in **on the device** (no backend needed). The password
for all of them is `MsuDemo#2026`. On the login screen, *Masuk dengan akun
demo* fills them in for you.

| Email | Name | Persona |
|---|---|---|
| `rani@msu.demo` | Rani | Mahasiswi tingkat 2 |
| `dimas@msu.demo` | Dimas | Mahasiswa tingkat akhir |
| `aisyah@msu.demo` | Aisyah | Mahasiswi baru |
| `budi@msu.demo` | Pak Budi | Jamaah MSU |
| `salsa@msu.demo` | Bu Salsa | Dosen dan civitas akademika |

Any other email and password go to the backend `POST /auth/login`. Build
with `--dart-define=DEMO_LOGIN=false` to remove the demo accounts; a `prod`
build refuses to start while they are on.

## Production build

```sh
flutter build appbundle --release --dart-define=APP_ENV=prod \
  --dart-define=DEMO_LOGIN=false --dart-define=API_BASE_URL=https://<api-host> \
  --obfuscate --split-debug-info=build/symbols
```

A `prod` build refuses to start with the demo accounts on or with the
placeholder API URL. Release signing reads `android/key.properties` (not
committed). See [SECURITY.md](SECURITY.md).

## Code generation

Models use `freezed` + `json_serializable`; providers use
`riverpod_generator`.

```sh
dart run build_runner build -d   # one-off
dart run build_runner watch -d   # while developing
```

## Quality checks

```sh
dart format .
flutter analyze        # very_good_analysis + riverpod_lint, 0 issues
flutter test           # unit + widget tests
```

CI (`.github/workflows/flutter_ci.yml`) runs the same steps on every push and
pull request to `main` and `develop`.

## Folder structure

```
lib/
├── main.dart          # bootstrap: config, prefs, ProviderScope
├── app.dart           # MaterialApp.router, theme, l10n
├── core/              # config, theme, router, network, storage, security,
│                      # logging, utils, shared widgets
├── features/
│   ├── auth/          # splash, login, lock screen, session
│   ├── onboarding/    # intro slides, consent
│   ├── home/          # Beranda
│   ├── assessment/    # report list + detail
│   ├── checkin/       # mood check-in + weekly strip
│   ├── chat/          # AI assistant + psychologist (WhatsApp)
│   ├── learn/         # garden, exercises, articles
│   ├── crisis/        # crisis help
│   ├── remote_config/ # WhatsApp number, crisis contacts, consent version
│   └── profile/       # profile, privacy, consent history, app lock, theme
└── l10n/              # app_id.arb (Bahasa Indonesia)
test/                  # mirrors lib/
```

Each feature is layered `data/` → `domain/` → `presentation/`. Screens go
through controllers (Riverpod) to repositories, which return `Result<T>`.
Tests replace the backend with fakes in `test/helpers/fakes.dart`.

## Privacy & security notes

- Tokens, chat history, consent, and the app-lock flag live in
  `flutter_secure_storage`; `shared_preferences` holds only UI preferences.
- Logs contain event names and error types only, never user content.
- Chat, report detail, and "Lepaskan pikiran" block screenshots
  (`FLAG_SECURE`); Android backups are disabled.
- The WhatsApp link carries only a generic greeting.
- Logout clears tokens, chat history, consent, and cached user data.

## Notes on the spec

- **minSdk 24** instead of 23: Flutter 3.47 does not support API 23.
- **`custom_lint` is not used:** `riverpod_lint` 3 runs as a native analyzer
  plugin.
- Code uses Dart 3.13 constructor syntax (`const new(...)`), as required by
  `very_good_analysis` 11.
- Open items (official MSU color, WhatsApp number, verified crisis contacts,
  final API, reviewed articles, audio files) are marked `TODO(DKMSU)` /
  `TODO(backend)` in code.

## Team and roles

_To be filled in._

## License

The product belongs to MSU per the DKMSU agreement. Third-party assets are
listed in [ASSETS.md](ASSETS.md).
