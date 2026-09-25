# MindMitra 🌿
### AI-Based Cognitive Gaming & Memory Assistance Platform for Elderly Dementia Patients in the North Eastern Region (NER)

**Smart India Hackathon (SIH 2026)**  
- **Problem Statement ID:** `SIH26003`  
- **Theme:** MedTech / BioTech / HealthTech  
- **Category:** Software  
- **Team Name:** Nova Matrix (Team ID: 166756)  
- **Target Audience:** Elderly individuals suffering from mild cognitive impairment (MCI) or dementia in remote/rural areas of North Eastern India, along with their family caregivers.

---

## 🌟 Solution Overview

**MindMitra** is an accessible, voice-enabled, offline-first cognitive health companion designed specifically for older adults and their caregivers. Rather than acting as an intimidating diagnostic test, MindMitra provides gentle daily mental stimulation, tracks subtle changes in participation, adapts difficulty automatically, and keeps caregivers connected.

### Key Architectural Pillars:
1. **Elderly-Friendly & Accessible UI/UX**: Extra-large touch targets (64px buttons), high-contrast text (sizes 18–34), soothing color palette (Cream `#FAF6EC`, Sage Green `#8FAE8B`, Warm Yellow `#F4C95D`), and predictable navigation.
2. **4 Core Cognitive Games**:
   - 🃏 **Memory Match**: Object & symbol recall (2 to 4 pairs).
   - 🔢 **Sequence Game**: Simon-Says visual and working memory exercise.
   - 👀 **Attention Game**: Sustained vigilance and focus test (star-spotting).
   - 🔷 **Pattern Game**: Visual logic and sequential pattern deduction.
3. **AI/ML Engine**:
   - Evaluates response time, error patterns, accuracy, and consistency.
   - **Adaptive Difficulty Controller (Levels 1–3)**: Dynamically scales game complexity up or down so patients are never frustrated or overwhelmed.
   - **Cognitive Score Calculation (0–100)**: Multi-domain assessment across Memory Recall, Sustained Attention, Working Sequence, Visual Pattern, and Processing Speed.
   - **Personalized Daily Activity Recommendation**: Recommends the optimal daily practice based on the domain that needs gentle stimulation.
4. **Voice Assistance & Regional Language Support (NER Focus)**:
   - Voice guidance with text-to-speech feedback and visual subtitles for hard-of-hearing users.
   - Natural language voice commands (e.g. *"Start memory game"*, *"Call my caregiver"*, *"How is my progress?"*).
   - **Multilingual Support for North Eastern Region**:
     - English
     - हिन्दी (Hindi)
     - অসমীয়া (Assamese - Primary language of Assam & NER)
     - বাংলা (Bengali - Widely spoken in Tripura & Barak Valley)
5. **Offline-First Resilience & Cloud Sync**:
   - Built to operate seamlessly in remote/rural North Eastern areas with intermittent or zero internet connectivity.
   - All sessions are cached locally using an offline-first repository.
   - Automatically synchronizes to the cloud (Firebase Firestore architecture) once connectivity resumes.
6. **Caregiver Monitoring Dashboard**:
   - **Dual-Mode Experience**: Switch between Patient View (encouraging, simple, streak-focused) and Caregiver View (detailed domain charts, session logs, reaction time metrics).
   - Caregiver link and emergency contacts (Primary Caregiver, Neurologist, Elderline 14567).
   - Shareable caregiver summary reports.

---

## 👥 Team Roles & Modules Implemented

| Member | Role | Deliverables in Codebase |
| :--- | :--- | :--- |
| **Ganga** | Team Lead + UI/UX | High-contrast accessible design system, `AppTheme`, navigation shell (`MainShell`), and calming visual components. |
| **Nivya** | Cognitive Games Developer | Developed 4 cognitive games: `MemoryGame`, `SequenceGame`, `AttentionGame`, and `PatternGame` in `lib/games/`. |
| **Rishika** | AI/ML Developer | `AIEngine`: Performance analysis, adaptive difficulty algorithms, cognitive score calculator, and daily activity recommender. |
| **Pooja guru** | Backend Developer | `StorageService` & Models: Structured schemas for `GameSession`, `PatientProfile`, `CognitiveScore`, offline caching, and Firestore synchronization. |
| **Safa Rosan** | Voice + Offline Developer | `VoiceService` & `LocalizationService`: Voice assistant, multilingual dictionaries (Assamese, Bengali, Hindi, English), and offline continuity toggle. |
| **Shafas** | Caregiver Dashboard + Testing | `ProgressScreen`: Caregiver dashboard, cognitive radar/domain breakdown, session history, report export, and test suite. |

---

## 📁 Project Structure

```
lib/
├── main.dart                       # App entry point, storage & AI initialization
├── models/
│   ├── cognitive_score.dart        # Domain indices & overall wellness score model
│   ├── game_session.dart           # Session record (duration, mistakes, score, sync status)
│   └── patient_profile.dart        # Elderly user & linked caregiver details
├── services/
│   ├── ai_engine.dart              # AI adaptive difficulty & cognitive calculations
│   ├── localization_service.dart   # NER multilingual translations (EN, HI, AS, BN)
│   ├── storage_service.dart        # Offline-first repository & Firebase sync simulation
│   └── voice_service.dart          # Voice assistant & natural language command parser
├── games/
│   ├── games_screen.dart           # Cognitive Games hub with AI level indicators
│   ├── memory_game.dart            # Memory matching pairs game
│   ├── sequence_game.dart          # Sequential Simon-says game
│   ├── attention_game.dart         # Sustained attention star game
│   └── pattern_game.dart           # Pattern deduction shape game
├── screens/
│   ├── main_shell.dart             # Shell with NER language switcher & offline badge
│   ├── home_screen.dart            # Greeting, mood check-in, recommended activity, quick call
│   ├── progress_screen.dart        # Caregiver & Patient analytics dashboard
│   └── help_screen.dart            # Voice companion ("MindMitra Saathi") & emergency speed dial
├── theme/
│   └── app_theme.dart              # High-accessibility color palette & typography
└── widgets/
    └── mind_card.dart              # Reusable accessible rounded card widget
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.13 or newer)
- Chrome / Edge (for Web testing) or Windows / Android / iOS device.

### Running the App
1. Clone or open the repository directory:
   ```bash
   cd Mind-Mitra-main
   ```
2. Get packages:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   # Run in Chrome browser
   flutter run -d chrome

   # Or run on Windows Desktop
   flutter run -d windows
   ```

### Running Tests
```bash
flutter test
```

---

## 🛡️ Non-Diagnostic Disclaimer
*MindMitra is designed to provide cognitive engagement, gentle daily mental practice, and non-clinical visibility for caregivers. It is not a medical device, nor does it provide formal medical diagnosis or replace professional neurological care.*
