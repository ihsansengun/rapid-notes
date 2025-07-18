
# 📱 QuickDump – Instant Thought Capture App

## 🔷 Overview
**QuickDump** is an iOS-first micro note-taking app designed to help users instantly capture short, spontaneous ideas during inconvenient moments — like watching a movie, walking, or commuting. Unlike traditional note apps, QuickDump is optimized for **speed**, **frictionless UX**, and **AI-powered recall**.

## 🧭 Problem
Modern note-taking apps are too slow and complex for capturing quick, impulsive thoughts. Unlocking your phone, opening an app, finding a field, and saving the note adds too much friction — causing ideas to be lost.

## ✅ Solution
An ultra-fast app accessible from the iOS **lock screen** or **Apple Watch**, with voice-first capture, location tagging, and AI-powered summarization. No menus, no distractions — just **one tap to dump** your thought and move on.

## 🔥 Core Value Propositions
| Value | Description |
|-------|-------------|
| ⚡️ Fast Access | Via Lock Screen Widget or Apple Watch tap |
| 🧠 Thought Dumping UX | One-tap, no-structure capture of fleeting ideas |
| 🎙 Voice-First | App opens directly into recording mode |
| 📍 Auto-Context | Timestamp + Location recorded with each note |
| 🤖 Smart Recall | AI rephrasing, organizing, and reminding you later |

## 💡 Use Case Scenarios
| Scenario | Flow |
|----------|------|
| 📽 In a movie theater | Tap Watch → record “Wong Kar Wai film” |
| 🚶 On the move | Tap Lock Widget → dictate “Fix shoe app UI” |
| 🛏 Before bed | App reminds you of your day’s thoughts |
| 🧠 Mid-meeting insight | Type quickly → saved instantly |
| 📍 Revisit place, trigger memory | App surfaces past notes from that location |

## 🧱 Feature Breakdown

### 🔹 Core Features (MVP)
| Feature | Description |
|---------|-------------|
| 🟢 Lock Screen Widget | Tap to open app instantly (via WidgetKit) |
| 🟢 Auto Voice Recording | App opens directly into active voice capture |
| 🟢 Optional Text Input | Keyboard also available and auto-focused |
| 🟢 Instant Save | No save button; autosaves on exit |
| 🟢 Timestamp + Location Tag | Stored with each note in background |
| 🟢 AI Labeling (Simple) | Classifies note into type: movie/book/idea/task |
| 🟢 Reminder Prompt (Evening) | “Want to revisit your notes today?” |

### 🔹 Future Features (V2+)
| Feature | Description |
|---------|-------------|
| 🔵 AI Note Expansion | Turn “film idea” into full, coherent entry |
| 🔵 Natural Language Reminders | “Remind me when I’m in Paris” style follow-ups |
| 🔵 Cloud Sync (Optional) | iCloud or Firebase backup/sync |
| 🔵 Search & Tags | Filter notes by keyword, label, or time |
| 🔵 Spotlight Integration | Access notes via iOS global search |
| 🔵 Apple Watch Voice App | Companion for voice-first capture anywhere |

## 🚀 User Flow (MVP)

### 📲 From iPhone Lock Screen:
1. Tap Widget
2. Face ID unlocks phone (automatic)
3. App launches directly into voice mode (recording starts)
4. Speak your note
5. Recording ends after pause or tap
6. Note saved with timestamp + location
7. Optionally: type/edit the same note

### ⌚ From Apple Watch:
1. Tap complication or shortcut
2. Record voice (speech-to-text)
3. Sent to paired iPhone
4. Auto saved

## 🎨 UI Concepts (Wireframe Summary)
1. **Lock Screen Widget**: “+ Note” button – opens app.
2. **Launch Screen**:
   - Voice recording auto-starts.
   - Optional "type instead" button (autofocus on field).
3. **Note Saved View**:
   - Timestamp + Location shown.
   - Optional AI label or suggestion.
4. **Notes List**:
   - Chronological view with filters.
   - Each note shows label + quick actions (edit, delete, AI expand).

## 🧠 AI Integration Roadmap
| AI Use Case | Phase | Description |
|-------------|-------|-------------|
| Voice to text transcription | MVP | Clean, lightweight, fast speech-to-text |
| Note classification (tags) | MVP | Movie / Book / Task / Idea etc. |
| Contextual recall suggestions | V2 | Based on previous notes, time, or location |
| AI summarization/expansion | V2 | “Rewrite this” → long-form note from short idea |
| Smart reminders & grouping | V3 | “Here’s everything you noted about Paris” |

## 📦 Tech Stack (MVP)
| Component | Tooling |
|-----------|---------|
| App Framework | SwiftUI |
| Lock Widget | WidgetKit |
| Audio Handling | AVFoundation |
| Speech-to-Text | Apple Speech Framework / OpenAI Whisper API |
| Storage | CoreData / SQLite |
| Location | CoreLocation |
| AI Services | GPT-4 (via OpenAI API) |
| Notifications | UNUserNotificationCenter |
| Watch App (opt.) | WatchKit + WCSession |

## 🎯 MVP Success Metrics
- ⏱ Time from tap → note recorded (goal: < 2 seconds)
- 📈 Daily active notes taken
- 📍 # of notes with location metadata
- 🧠 % of notes reviewed later with reminder flow
- 🤖 AI tags assigned correctly (%)

## 💬 Tagline Ideas
- “The fastest notes you’ll ever take.”
- “For thoughts that strike when life is inconvenient.”
- “Don’t lose it. Dump it.”

## 🔓 Accessory Features (Future)
- iCloud sync
- Markdown export
- Calendar view of note history
- API/web companion
- Siri shortcut: “Hey Siri, dump note”
