# Overwatch Mystery Heroes Ultimate Challenge Tracker

A minimalist Flutter web app to track your progress through the **Overwatch Mystery Heroes Ultimate Challenge** — a fun challenge where you play a random hero every match and track when you've mastered their ultimate ability.

## 🎮 About the Challenge

The Mystery Heroes Ultimate Challenge is a personal gaming goal where you:

1. **Queue for Mystery Heroes** (where you get a random hero each spawn)
2. **Pick a random hero** from the 53-hero roster
3. **Earn their Ultimate Ability** during a match
4. **Complete the challenge** when you've landed an ultimate with that hero
5. **Repeat** until you've mastered all heroes!

Track your progress and see how long it takes you to complete the full roster.

## ✨ Features

- **53-Hero Roster**: Complete Overwatch 2 hero list with role categories (Tank, Damage, Support)
- **Visual Hero Cards**: Each hero displays their in-game image for easy identification
- **Three Views**: cycle with the view button in the app bar —
  - **Board** (default): the whole roster on a whiteboard in TANKS / DPS / SUPPORTS
    columns, with a `23/53` tally on the banner. Click a portrait to grey it out as
    complete; click again to undo.
  - **A–Z**: In Progress and Complete side by side, alphabetically
  - **By Role**: the same split, grouped into Tanks / Damage / Support
- **Progress Tracking**: Tap a hero to move them between "In Progress" and "Complete"
  as you master their ultimates. The chosen view is remembered along with your progress.
- **Timer**: Track elapsed time since your last reset
- **Persistent State**: Your progress is saved locally in your browser
- **Optional Cloud Sync**: Sign in with Google to sync progress across devices via Firestore.
  The signed-in account is never shown on screen, so the board is safe to put on stream.
- **Reset Function**: Start fresh with a new challenge run

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or later) — the `pubspec.yaml` constraint is `>=3.0.0 <4.0.0`
- Dart
- A Firebase project (see *Firebase configuration* below)

> This is a **web-only** project — only `web/` platform scaffolding is checked in, so
> there is no mobile build target.

### Installation

1. Clone the repository:
```bash
git clone https://github.com/tjeffree/Overwatch-Mystery-Heroes.git
cd Overwatch-Mystery-Heroes
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app — web only, and Firebase values must be passed in (see below):
```bash
flutter run -d chrome \
  --dart-define=APIKEY=... \
  --dart-define=APPID=... \
  --dart-define=MESSAGINGSENDERID=... \
  --dart-define=PROJECTID=... \
  --dart-define=STORAGEBUCKET=... \
  --dart-define=AUTHDOMAIN=...
```

### Firebase configuration

There is no `firebase_options.dart` in this repo. `main()` builds `FirebaseOptions` from
compile-time environment values via `String.fromEnvironment`, so all six must be supplied
with `--dart-define`:

`APIKEY`, `APPID`, `MESSAGINGSENDERID`, `PROJECTID`, `STORAGEBUCKET`, `AUTHDOMAIN`

`Firebase.initializeApp` is called unconditionally at startup and is not guarded, so
running or building **without** these will fail to start rather than degrade gracefully.
In CI they come from GitHub Actions repository secrets of the same names.

## 🌐 Live Demo

The app is deployed to GitHub Pages on a custom domain:
[https://mysteryheroesmashup.com](https://mysteryheroesmashup.com)

(The old `tjeffree.github.io/Overwatch-Mystery-Heroes/` address still works — it redirects
to the custom domain.)

## 📦 Building for Production

To build the web app for deployment:
```bash
flutter build web --base-href "/" \
  --dart-define=APIKEY=... --dart-define=APPID=... \
  --dart-define=MESSAGINGSENDERID=... --dart-define=PROJECTID=... \
  --dart-define=STORAGEBUCKET=... --dart-define=AUTHDOMAIN=...
```

The base href is `/` because the site is served from the root of a custom domain, not from
a repository subpath.

The build is deployed to GitHub Pages via GitHub Actions on pushes to `main`, using
repository secrets for the Firebase values. Commits that only touch `.claude/**` or
Markdown files are skipped by the workflow's `paths-ignore`, since they can't change the
built output.

## 🏗️ Project Structure

```
lib/
  ├── main.dart          # App, state, sync, and the two list views
  └── board_view.dart    # The whiteboard board view (layout, tiles, painters)

web/
  ├── index.html         # Web entry point
  ├── manifest.json      # PWA configuration
  └── icons/             # App icons and favicon

assets/
  ├── *.webp             # Hero portrait images (53 heroes)
  └── fonts/             # Permanent Marker, the handwritten face on the board

.github/workflows/
  └── gh-pages.yml       # Build and deploy to GitHub Pages

.claude/skills/
  └── add-overwatch-hero/  # Workflow for adding a newly released hero
```

## 📝 Technologies Used

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **shared_preferences**: Local state persistence
- **firebase_core / firebase_auth**: Firebase setup and Google sign-in
- **cloud_firestore**: Cloud sync of progress for signed-in users
- **Material 3**: Modern design system

## 🎯 Hero Roster

**Tanks (15)**: D.Mon, D.Va, Domina, Doomfist, Hazard, Junker Queen, Mauga, Orisa, Ramattra, Reinhardt, Roadhog, Sigma, Winston, Wrecking Ball, Zarya

**Damage (24)**: Anran, Ashe, Bastion, Cassidy, Echo, Emre, Freja, Genji, Hanzo, Junkrat, Mei, Pharah, Reaper, Shion, Sierra, Sojourn, Soldier: 76, Sombra, Symmetra, Torbjörn, Tracer, Vendetta, Venture, Widowmaker

**Support (14)**: Ana, Baptiste, Brigitte, Illari, Jetpack Cat, Juno, Kiriko, Lifeweaver, Lúcio, Mercy, Mizuki, Moira, Wuyang, Zenyatta

## 📄 License

This project is open source and available under the MIT License.

The bundled `assets/fonts/PermanentMarker-Regular.ttf` is Permanent Marker by Font Diner,
distributed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests

## 💬 Questions?

If you have any questions or feedback about this project, feel free to open an issue on GitHub!

---

Happy ulting! 🎯