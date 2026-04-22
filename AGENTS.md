# Eyadati - Agent Instructions

## Build Commands

```bash
flutter analyze      # lint + static analysis
flutter run          # run on device/emulator
flutter build web   # build PWA
flutter build apk   # build Android APK
```

## Key Architecture

- **Web-Only PWA** - Serving all platforms via browser (phone, tablet, desktop)
- **Two user flows**: Clinic owners and regular users
- **Backend**: Firebase (Auth/Firestore) + Supabase (Storage/Edge Functions)
- **Payments**: Chargily Pay via Supabase edge function `create-chargily-checkout`
- **State management**: Provider package
- **i18n**: easy_localization (en, fr, ar) in `assets/translations/`

## Responsive Breakpoints

| Screen Width | Navigation | Layout |
|------------|-----------|--------|
| **< 600px** | Bottom nav bar | Stacked pages |
| **600-900px** | Collapsible sidebar | 2-column |
| **> 900px** | Persistent sidebar | Full dashboard |

## Existing Responsive Patterns (KEEP THESE!)

```dart
// Booking dialogs: Desktop = Dialog, Mobile = Bottom Sheet
if (MediaQuery.of(context).size.width > 900) {
  return showDialog(...);
}
return showMaterialModalBottomSheet(...);

// Navigation switching handled in clinic_nav_bar.dart
```

## Critical Quirks

### Supabase Edge Functions
- `supabase/functions/chargily-webhook/index.ts` - payment webhook handler
- `supabase/functions/fcm_notifications/index.ts` - FCM notifications
- Webhook secret is hardcoded (test key in repo)

### Provider Initialization
```dart
Provider.debugCheckInvalidValueType = null;  // Required in main.dart
```

### Image Storage
Clinic avatars uploaded to Supabase Storage, not Firebase Storage.

## Directory Structure

| Directory | Purpose |
|-----------|---------|
| `lib/clinic/` | Clinic registration, login, appointments, settings |
| `lib/user/` | User profile, appointments |
| `lib/Appointments/` | Booking logic, clinic lists, slots UI |
| `lib/NavBarUi/` | Navigation bars, appointment management |
| `lib/chargili/` | Chargily payment integration |
| `lib/Themes/` | Light/dark theme definitions |
| `lib/utils/` | Utilities, helpers, models |
| `supabase/functions/` | Supabase Edge Functions (backend) |

## Entry Point

`lib/main.dart` → `flow.dart` → routes to clinic or user flow based on auth state.

## No Existing Tests

The project has `flutter_test` as a dev dependency but no test files or test scripts configured.