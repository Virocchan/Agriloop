# AgriLoop Mobile — Flutter Application
**Smart Community Composting & Circular Waste Diversion for Sime Darby Communities**

---

## 📱 Tech Stack & Libraries
- **Framework**: Flutter (Dart 3.3+)
- **State Management**: `flutter_riverpod` (Riverpod 2.5+)
- **Navigation & Routing**: Stateful navigation shell & bottom bar
- **Backend & Realtime**: `supabase_flutter` (Auth, Postgres, Realtime, Storage)
- **Scanning & Codes**: `mobile_scanner` (Camera QR scanning for bins & merchant vouchers), `qr_flutter` (Dynamic signed voucher QR rendering)
- **Typography & Styling**: `google_fonts` (Plus Jakarta Sans & Space Grotesk) with custom eco-tech dark theme

---

## 📂 Architecture Overview

```
agriloop_mobile/
├── pubspec.yaml                 # Dependencies and assets
├── assets/
│   └── images/
│       ├── smart_bin.jpg        # 3D cutaway render of AgriLoop Bokashi bin
│       ├── deposit_clean.jpg    # ESP32-CAM clean deposit view
│       └── deposit_contaminated.jpg # ESP32-CAM contamination detected view
└── lib/
    ├── main.dart                # Application entrypoint & ProviderScope
    ├── core/
    │   └── theme/
    │       └── app_theme.dart   # Eco-tech design tokens & typography
    ├── models/
    │   └── all_models.dart      # UserProfile, SmartBin, DepositRecord, Voucher, Batch, Task
    ├── providers/
    │   └── app_state_provider.dart # StateNotifier & Riverpod state store
    └── features/
        ├── resident/
        │   ├── resident_shell.dart         # Main bottom navigation & top bar
        │   ├── home_tab.dart               # Points, streak, impact stats, nearest bin
        │   ├── deposit_scanner_tab.dart    # QR scanner, 30s unlock timer, AI verdict
        │   ├── rewards_tab.dart            # Merchant voucher catalogue & QR pass
        │   ├── community_tab.dart          # Block leaderboard & weekly challenges
        │   ├── profile_tab.dart            # Bokashi 101 guide & problem reporting
        │   └── inbox_screen.dart           # In-app notifications
        ├── merchant/
        │   └── merchant_screen.dart        # Cashier voucher scanner & HMAC verify
        └── operator/
            └── operator_dashboard_screen.dart # Fleet telemetry, batches & compost log
```

---

## 🚀 Running the App

### 1. Prerequisites
Ensure you have the Flutter SDK installed on your machine (`>= 3.3.0`).

### 2. Install Dependencies
```bash
cd agriloop_mobile
flutter pub get
```

### 3. Run on Connected Device / Simulator
```bash
# Run on iOS Simulator
flutter run -d iOS

# Run on Android Emulator
flutter run -d android

# Run on Chrome / Web
flutter run -d chrome
```

---

## 🔑 Key Workflows Implemented
1. **Resident Role**:
   - Live reward points & streak tracking
   - Real-time nearest smart bin status (fill %, internal temp, available/offline)
   - Scan & Deposit simulation with 30s solenoid countdown
   - Dual-photo ESP32-CAM comparison with AI contamination inspection
   - Partner merchant voucher redemption (Jaya Grocer, Zus Coffee, Tealive, Village Grocer)
   - Block vs Block monthly leaderboard
   - In-app problem reporting directly dispatching to operator queue
2. **Merchant Role**:
   - Cashier scanner interface for customer voucher QR passes
   - HMAC token verification simulation
   - Today's redemption history & running RM payout ledger
3. **Operator Role**:
   - Real-time smart bin fleet telemetry (gross weight, fill %, temp, RSSI, lock status, remote unlock)
   - Maintenance task list (bucket swap, bran refill, tea draining)
   - 14-day anaerobic Bokashi batch tracker
   - Compost return logging form (instantly updates resident community progress bar!)
