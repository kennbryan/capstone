# Assets

Every bundled asset must be free to use in the app. Record the source and
license here before adding a file.

## Fonts

| File | Source | License |
|---|---|---|
| `assets/fonts/PlusJakartaSans-Regular.ttf` (400) | [tokotype/PlusJakartaSans](https://github.com/tokotype/PlusJakartaSans) | SIL Open Font License 1.1 (`assets/fonts/OFL.txt`) |
| `assets/fonts/PlusJakartaSans-Medium.ttf` (500) | same | same |
| `assets/fonts/PlusJakartaSans-SemiBold.ttf` (600) | same | same |
| `assets/fonts/PlusJakartaSans-Bold.ttf` (700) | same | same |

## Audio

The three "Suara tenang" loops are synthesized by the team with
[`tool/generate_sounds.py`](tool/generate_sounds.py): rain, forest (wind and
birds), and waves, built from shaped noise and simple tones. They are not
recordings, so there is no third-party license. **License: CC0 (public domain),
© MSU Well-being team.**

| File | Sound | Format |
|---|---|---|
| `assets/audio/rain.wav` | Hujan | 40 s seamless loop, mono, 32 kHz |
| `assets/audio/forest.wav` | Hutan | same |
| `assets/audio/waves.wav` | Ombak | same |

WAV is used because it loops with no gap on both Android and iOS (MP3/AAC add
encoder padding; Ogg does not play on iOS). Regenerate with
`python tool/generate_sounds.py`. To swap in real recordings, keep the file
names and record the source and license here.

## MSU logo

| Expected file | Source | License |
|---|---|---|
| `assets/images/msu_logo.png` (square, transparent, ≥ 512 px) | _TODO(DKMSU): official file_ | Owned by MSU |

Until the file exists, `MsuLogo` draws a simple placeholder mark (a dome on
the brand gradient with "MSU"). Adding the PNG replaces it everywhere
(splash, login, lock, Beranda, About) with no code change.

## Illustrations and icons

All artwork is drawn in code (`CustomPainter`), follows the theme palette,
and has a dark-mode version automatically. No image files, so nothing to
license.

| Artwork | Code |
|---|---|
| Illustration set: onboarding (companion, AI vs psychologist, help), empty states (no report, no check-ins, chat, psychologist away, offline, calm), header plant | `lib/core/widgets/illustrations/` |
| Mood faces 1–5 | `lib/features/checkin/presentation/widgets/mood_face.dart` |
| Assistant avatar | `lib/features/chat/presentation/widgets/assistant_avatar.dart` |
| Time-of-day sky (pagi, siang, sore, malam) | `lib/features/home/presentation/widgets/day_sky.dart` |
| Garden stages (seed → sprout → small plant → bud → flower) | `lib/features/learn/presentation/widgets/garden_painter.dart` |
| Exercise tile art, sound scenes (rain, forest, waves) | `lib/features/learn/presentation/widgets/learn_art.dart`, `sound_scene.dart` |
| Exercise background shapes | `lib/core/widgets/soft_blobs.dart` |
| Placeholder logo, mood trend chart, breathing orb | `msu_logo.dart`, `mood_trend_chart.dart`, `breathing_widgets.dart` |

**Style rules:** soft rounded flat shapes, theme greens with one warm accent
(sun/flowers) and one cool accent (AI only); no outlines heavier than the
icon stroke; no Islamic or geometric patterns; no red outside crisis UI;
nothing wilted, broken, or sad-looking.

Icons: Material Icons, bundled with Flutter (Apache License 2.0).
