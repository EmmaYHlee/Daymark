# Daymark
Daymark is a simple daily goal-tracking app that helps you build habits, track your progress, and stay consistent.

## Tech Stack
- **Language:** Swift
- **Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Platform:** iOS 17.0+
- **Development Environment:** Xcode

## Getting Started

### Requirements

- macOS
- Xcode
- iPhone running iOS 17.0 or later

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/EmmaYHlee/Daymark.git
   ```

2. Open `Daymark.xcodeproj` in Xcode.
3. Select your iPhone or an iOS Simulator as the run destination.
4. Configure your Apple Developer Team under **Signing & Capabilities**.
5. Build and run the project using `Command + R`.


## Files
Models/: the SwiftData models Goal, CheckIn, Achievement and Reflection.
Theme/: the 8 gradient presets, each with light and dark variants and a readable text colour, plus light/dark/system appearance.
Engine/: weekly progress and streak logic, achievements, local announcements, notification scheduling and haptics.
Views/: all 9 screens from your spec (splash, home, create/edit goal, goal detail, monthly calendar, stats, and the three settings screens), plus the confetti and animated checkmark.

## Features

- **Daily Goal Tracking** — Organize and keep track of your personal goals.
- **Progress Visualization** — Monitor your completion and see how far you've come.
- **Statistics** — Review your progress through a dedicated statistics dashboard.
- **Persistent Storage** — Keep your goals and progress saved locally using SwiftData.
- **Native iOS Experience** — Built with SwiftUI, featuring native navigation and a custom visual design.
- **Motivational Splash Screen** — Start each session with an encouraging reminder to keep moving forward.


## 📱 App Structure

| Tab | Description |
|---|---|
| Home | Manage and track daily goals |
| Progress | View statistics and monitor progress |
| Settings | Manage app preferences |




*Made with SwiftUI and a little everyday optimism.*
