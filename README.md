# Rapid Notes (QuickDump)

A SwiftUI-based iOS note-taking app designed for instant thought capture with voice-first recording and lock screen widget access.

## Features

### Core Functionality
- **Voice-First Capture** - Auto-starts recording on launch
- **Lock Screen Widget** - Instant access from iPhone lock screen
- **Auto-Save** - No save button needed, everything saves automatically
- **Location Tagging** - Automatic location capture with notes
- **AI Integration** - Note classification and smart tagging
- **Dark Theme** - Minimalistic dark interface design

### Platform Support
- **iOS 18.5+** (primary target)
- **macOS 15.5+** (secondary support)
- **Lock Screen Widgets** - Multiple widget sizes supported

### Widget Types
- **System Small** - Quick voice recording button
- **System Medium** - New note + recent note preview
- **Accessory Inline** - Lock screen inline widget
- **Accessory Rectangular** - Lock screen rectangular widget

## Technical Architecture

### Technologies Used
- **SwiftUI** - Modern iOS UI framework
- **WidgetKit** - Lock screen and home screen widgets
- **AVFoundation** - Audio recording and playback
- **Speech Framework** - Speech-to-text conversion
- **CoreLocation** - Location services
- **CoreData** - Local data persistence
- **App Groups** - Data sharing between app and widget

### Project Structure
```
Rapid Notes/
├── Rapid Notes/              # Main app target
│   ├── Rapid_NotesApp.swift  # App entry point
│   ├── ContentView.swift     # Main interface
│   ├── NewNoteView.swift     # Note creation view
│   ├── NoteDetailView.swift  # Note viewing/editing
│   ├── Services/             # Core services
│   │   ├── SpeechService.swift
│   │   ├── LocationService.swift
│   │   └── AIService.swift
│   └── Data/                 # Core Data models
├── QuickDumpWidgetExtension/ # Widget extension
│   ├── QuickDumpWidget.swift # Widget implementation
│   └── QuickDumpWidgetExtensionBundle.swift
└── WidgetInfo.plist         # Widget configuration
```

## Setup & Installation

### Prerequisites
- Xcode 15.0+
- iOS 18.5+ device or simulator
- Apple Developer Account (for device testing)

### Configuration
1. Clone the repository
```bash
git clone https://github.com/ihsansengun/rapid-notes.git
cd rapid-notes
```

2. Open the Xcode project
```bash
open "Rapid Notes.xcodeproj"
```

3. Configure API Keys (optional for AI features)
```bash
# Create .env file in Rapid Notes/ folder
echo "OPENAI_API_KEY=your_openai_api_key_here" > "Rapid Notes/.env"
```

4. Build and run
- Select your target device/simulator
- Build and run the project (⌘+R)

### Build Commands
```bash
# Build for iOS Simulator
xcodebuild -project "Rapid Notes.xcodeproj" -scheme "Rapid Notes" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild -project "Rapid Notes.xcodeproj" -scheme "Rapid Notes" test

# Build for device
xcodebuild -project "Rapid Notes.xcodeproj" -scheme "Rapid Notes" build
```

## Usage

### Quick Start
1. Launch the app to start voice recording immediately
2. Speak your note - it will be transcribed automatically
3. Location and timestamp are added automatically
4. Add the widget to your lock screen for instant access

### Widget Setup
1. Long press on iPhone lock screen
2. Tap "Customize"
3. Add widgets → Search "QuickDump"
4. Choose your preferred widget size
5. Tap anywhere on widget to open app and start recording

### Voice Recording
- App auto-starts recording on launch
- Tap microphone button to toggle recording
- Speech is converted to text automatically
- Notes save automatically without user action

## Permissions

The app requires the following permissions:
- **Microphone** - For voice recording
- **Speech Recognition** - For speech-to-text conversion
- **Location Services** - For automatic location tagging
- **Notifications** - For reminder functionality

## Development

### App Groups
The app uses App Groups capability (`group.Theory-of-Web.Rapid-Notes`) to share data between the main app and widget extension.

### Widget API Compatibility
- Uses iOS 17+ `containerBackground` API for proper widget display
- Supports multiple widget families and sizes
- Implements proper timeline providers for widget updates

### Core Data
- Local SQLite database for note storage
- Automatic migration support
- Optimized for quick note insertion and retrieval

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security

- API keys and sensitive data are excluded from version control
- Uses secure keychain storage for sensitive information
- Environment variables for configuration
- No hardcoded secrets in source code

## License

This project is proprietary software. All rights reserved.

## Bundle Information

- **Bundle ID**: `Theory-of-Web.Rapid-Notes`
- **Widget Bundle ID**: `Theory-of-Web.Rapid-Notes.QuickDumpWidgetExtension`
- **Minimum iOS Version**: 18.5
- **Minimum macOS Version**: 15.5

## Support

For issues, questions, or feature requests, please create an issue in this repository.

---

Built with ❤️ using SwiftUI and modern iOS technologies.