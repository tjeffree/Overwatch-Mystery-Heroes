# Overwatch Mystery Heroes Ultimate Challenge Tracker

A minimalist Flutter web app to track your progress through the **Overwatch Mystery Heroes Ultimate Challenge** — a fun challenge where you play a random hero every match and track when you've mastered their ultimate ability.

## 🎮 About the Challenge

The Mystery Heroes Ultimate Challenge is a personal gaming goal where you:

1. **Queue for Mystery Heroes** (where you get a random hero each spawn)
2. **Pick a random hero** from the 51-hero roster
3. **Earn their Ultimate Ability** during a match
4. **Complete the challenge** when you've landed an ultimate with that hero
5. **Repeat** until you've mastered all heroes!

Track your progress and see how long it takes you to complete the full roster.

## ✨ Features

- **51-Hero Roster**: Complete Overwatch 2 hero list with role categories (Tank, Damage, Support)
- **Visual Hero Cards**: Each hero displays their in-game image for easy identification
- **Progress Tracking**: Drag heroes from "In Progress" to "Complete" as you master their ultimates
- **Timer**: Track elapsed time since your last reset
- **Persistent State**: Your progress is saved locally in your browser
- **Reset Function**: Start fresh with a new challenge run

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or later)
- Dart

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

3. Run the app:
```bash
# For web
flutter run -d chrome

# For mobile
flutter run
```

## 🌐 Live Demo

The app is deployed to GitHub Pages and available at:
[https://tjeffree.github.io/Overwatch-Mystery-Heroes/](https://tjeffree.github.io/Overwatch-Mystery-Heroes/)

## 📦 Building for Production

To build the web app for deployment:
```bash
flutter build web --base-href "/Overwatch-Mystery-Heroes/"
```

The build is automatically deployed to GitHub Pages via GitHub Actions on every push to `main`.

## 🏗️ Project Structure

```
lib/
  └── main.dart          # Main app with all UI and state management

web/
  ├── index.html         # Web entry point
  ├── manifest.json      # PWA configuration
  └── icons/             # App icons and favicon

assets/
  └── *.webp             # Hero portrait images (51 heroes)
```

## 📝 Technologies Used

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **shared_preferences**: Local state persistence
- **Material 3**: Modern design system

## 🎯 Hero Roster

**Tanks (14)**: D.Va, Domina, Doomfist, Hazard, Junker Queen, Mauga, Orisa, Ramattra, Reinhardt, Roadhog, Sigma, Winston, Wrecking Ball, Zarya

**Damage (23)**: Anran, Ashe, Bastion, Cassidy, Echo, Emre, Freja, Genji, Hanzo, Junkrat, Mei, Pharah, Reaper, Sierra, Sojourn, Soldier: 76, Sombra, Symmetra, Torbjörn, Tracer, Vendetta, Venture, Widowmaker

**Support (14)**: Ana, Baptiste, Brigitte, Illari, Jetpack Cat, Juno, Kiriko, Lifeweaver, Lúcio, Mercy, Mizuki, Moira, Wuyang, Zenyatta

## 📄 License

This project is open source and available under the MIT License.

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests

## 💬 Questions?

If you have any questions or feedback about this project, feel free to open an issue on GitHub!

---

Happy ulting! 🎯