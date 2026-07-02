# Spring Festival Crush - Match 3

[![App Store](https://img.shields.io/badge/App%20Store-Available-blue)](https://apps.apple.com/app/spring-festival-crush-match-3/id1495828131)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)

## 🎮 Demo

<p align="center">
    <img src="./screenshots/1.gif" width="300" alt="Gameplay Demo">
</p>

## Overview

**Spring Festival Crush - Match 3** is a vibrant match-3 puzzle game that captures the essence of the Spring Festival. Immerse yourself in a world filled with festive joy, challenging puzzles, and stunning graphics that celebrate the season.

## ✨ Features

* 🎉 **Festive Theme**: Dive into the spirit of the Spring Festival with themed levels and elements that bring the celebration to life.
* 🧩 **Challenging Gameplay**: Overcome a variety of levels that increase in difficulty, offering endless fun and a test of your puzzle-solving skills.
* ⚡ **Smooth Experience**: Enjoy fluid animations and intuitive controls for a seamless gaming experience.
* 🎵 **Immersive Audio**: Experience traditional Chinese music and sound effects that enhance the festive atmosphere.
* 🌟 **Multiple Zodiac Themes**: Play through different Chinese zodiac animal themes with unique challenges.
* 📊 **Progress Tracking**: Save your progress and track your achievements across all levels.
* 💥 **Special Power-Up Tiles**: Earn powerful tiles through skillful matches for explosive chain reactions.
* ❤️ **Lives System**: Ten hearts pace your play session, regenerating over time — or refill instantly with a rewarded video.
* 🧰 **Pre-Level Boosters**: Spend coins earned from levels on extra moves or a tile-clearing hammer before a tough level.
* 🧩 **Rich Level Mechanics**: Multi-hit vault locks, spreading chocolate blockers, jelly overlays, ice-frozen tiles, ingredient-escort goals, and optional countdown timers.

## 📱 Screenshots

<p align="center">
    <img src="./screenshots/1.gif" width="200" alt="Gameplay">
    <img src="./screenshots/s1.webp" width="200" alt="Screenshot 1">
    <img src="./screenshots/3.png" width="200" alt="Screenshot 2">
</p>

## 🧳 Requirements

- **iOS Version**: iOS 17.0 or later
- **Compatible Devices**: iPhone, iPad
- **Xcode**: 15.0 or later
- **Swift**: 5.0+

## 💻 Installation

### iOS App Store

The game is available for download on the App Store. Click the link below to download:

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/app/spring-festival-crush-match-3/id1495828131)

### Local Development

1. **Clone the repository**:
   ```bash
   git clone https://github.com/banghuazhao/Spring-Festival-Crush.git
   cd Spring-Festival-Crush
   ```

2. **Open the project**:
   - Open `SpringFestivalCrush.xcodeproj` in Xcode
   - Select your target device or simulator

3. **Build and run**:
   - Press `Cmd + R` to build and run the project
   - Or click the "Play" button in Xcode

## 🎯 How to Play

1. **Match 3 or More**: Swipe to match three or more identical elements in a row to clear them from the board.
2. **Complete Objectives**: Meet the goals for each level within the allotted moves or time limit.
3. **Progress Through Levels**: Advance through increasingly difficult levels and unlock new challenges as you go.
4. **Unlock Zodiac Themes**: Complete levels to unlock different Chinese zodiac animal themes.

### 💥 Special Tiles

| Match | Tile | Effect |
|-------|------|--------|
| 4 in a row | 💥 Enhanced | Explodes all surrounding tiles with a shockwave |
| 5 in a row | 🌟 Universal (Five) | Swap with any tile to clear **every** tile of that type on the board |
| L / T shape | ⚡ Lightning | Clears the entire row **and** column instantly |
| 🔒 Lock | Lock | Requires an adjacent match to break free |
| ⛓️ Heavy Lock | Heavy Lock | Takes two adjacent matches to remove |

Special tiles can be swapped directly to trigger their effect at any time. Some levels start with one already on the board — a preview of what's to come, or a helping hand on a tougher level.

### 🧩 Level Elements

| Element | Behavior |
|---------|----------|
| 🔐 Vault Lock | Three-hit lock: vault → heavy lock → lock → cleared |
| 🍫 Chocolate | Clears like a lock, but spreads to an adjacent tile each move if left alone |
| 🟩 Jelly | A layer under the tile — keep matching over it to clear it, regardless of what's on top |
| 🧊 Ice | Freezes a tile in place; breaks one layer at a time when a neighboring match clears |
| 🎁 Ingredient | Guide it down to the bottom row to collect it |
| ⏱️ Timer | Some levels race the clock in addition to (or instead of) move count |

### ❤️ Lives & Boosters

- Start with 10 lives; one is spent each time you fail a level, regenerating over time.
- Out of lives? Watch a rewarded video for +1 life, or wait for the countdown.
- Before a tough level, spend coins (earned by completing levels) on a **+5 Moves** boost or a **Hammer** that clears one tile of your choice mid-level.

## 🏗️ Project Structure

```
SpringFestivalCrush/
├── Model/                 # Data models and game logic
│   ├── Game/             # Core game mechanics
│   ├── Level/            # Level data and objectives
│   ├── Music/            # Audio management
│   ├── Record/           # Progress tracking
│   └── Settings/         # App settings and themes
├── Scene/                # SpriteKit game scenes
├── View/                 # SwiftUI views and UI components
├── Assets.xcassets/      # Images and app icons
├── Sounds/               # Audio files
├── Levels/               # Level configuration files
└── Util/                 # Utility classes and extensions
```

## 🛠️ Development

### Tech Stack

- **Language**: Swift 5.0+
- **Game Framework**: SpriteKit
- **UI Framework**: SwiftUI
- **Concurrency**: Swift Concurrency (async/await)
- **Data Persistence**: SwiftData
- **Ad Integration**: Google AdMob
- **Build System**: Xcode

### Key Features

- **Modern Swift**: Leverages the latest Swift features including async/await and SwiftData
- **Performance Optimized**: Efficient memory management and smooth 60fps gameplay
- **Accessibility**: Supports VoiceOver and other accessibility features
- **Localization**: Available in English, Simplified Chinese, and Traditional Chinese

## 📋 Release Notes

### Version 3.0 (Latest)
- 🌟 New **Universal (Five)** power-up tile: match 5 in a row to earn it, then swap to clear every tile of one type
- ⚡ New **Lightning** power-up tile: formed from L/T-shape matches, clears an entire row and column at once
- 💥 **Double-lock** tile mechanic: heavy locks require two adjacent matches to break
- 🎨 Distinct activation effects for each power-up (shockwave ring, beam chain-link pull, yellow flash bar)
- 🐾 **Tiger** zodiac: 10 new levels added
- 📈 **Rat** and **Ox** zodiacs extended to 15 levels each
- 🔧 Enhanced tile now spawns at the exact position of the swapped tile
- ❤️ **Lives system**: 10 hearts, regenerating over time, with a rewarded-video refill option
- 🧰 **Pre-level boosters**: spend coins on +5 moves or a tile-clearing hammer before a level starts
- 🎬 **Rewarded video ads** for bonus lives and coins
- 🎓 **First-time tutorial hint** highlighting a real swappable pair on your very first level
- 🧩 **New level elements**: three-hit vault locks, spreading chocolate blockers, jelly overlays,
  ice-frozen tiles, ingredient-escort goals, and optional countdown timers — all authorable in any
  level's data, not just debug content
- 🌟 Special power-up tiles can now be **pre-placed in level data**, giving 17 levels across all
  three zodiacs a tutorial preview or a difficulty-easing assist
- 🖥️ Rebuilt in-game HUD as a proper component system (measured layout instead of hardcoded
  offsets, a single-banner hint system, a data-driven booster tray) — fixes a real layout bug
  where the HUD could balloon to fill the screen
- 🐛 Fixed candies falling straight through locks/blockers instead of stopping at them, then
  reworked hole-filling into a proper water-flow model (diagonal cascade around blockers) after
  the first fix left permanent gaps — and fixed a same-row variant of that fix that could freeze
  the game by oscillating forever between two blocked cells
- 🐛 Fixed selection indicator showing a broken-image cross on emoji-rendered tiles
- 🐛 Fixed rewarded ads failing to load (wrong ad format) and failing to present from inside a sheet
- 🐛 Fixed two levels with lock targets that mathematically exceeded the lock tiles available,
  making them unwinnable regardless of skill

### Version 2.0
- ✨ Enhanced graphics and animations
- 🎵 Improved audio experience with traditional Chinese music
- 🌟 Added new zodiac themes and levels
- 📊 Better progress tracking and achievements
- 🐛 Bug fixes and performance improvements

### Version 1.0
- 🎮 Initial release with core match-3 gameplay
- 🎨 Spring Festival themed graphics and elements
- 📱 Support for iPhone and iPad

## 🤝 Contributing

We welcome contributions to the project! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit your changes**: `git commit -m 'Add some amazing feature'`
4. **Push to the branch**: `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines

- Follow Swift style guidelines
- Add comments for complex logic
- Test on both iPhone and iPad
- Ensure accessibility compliance

## 🐛 Issues & Support

If you encounter any bugs or have suggestions:

- **GitHub Issues**: [Open an issue](https://github.com/banghuazhao/Spring-Festival-Crush/issues)
- **App Store Reviews**: Leave a review on the App Store
- **Email Support**: Contact us through the app settings

## 📞 Contact

Get in touch with us:

- **GitHub**: [@banghuazhao](https://github.com/banghuazhao)
- **App Store**: [Spring Festival Crush - Match 3](https://apps.apple.com/app/spring-festival-crush-match-3/id1495828131)
- **Email**: Contact through the app settings
- **Website**: [GitHub Repository](https://github.com/banghuazhao/Spring-Festival-Crush)

For business inquiries or collaboration opportunities, please reach out through GitHub or the app.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 🙏 Acknowledgments

- Traditional Chinese music and sound effects
- Spring Festival cultural elements and themes
- The SpriteKit and SwiftUI communities
- All beta testers and contributors

---

© 2019 - 2026 **Spring Festival Crush - Match 3** by Appsbay. All rights reserved.
