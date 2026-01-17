# Technology Stack

This document outlines the technology stack for the Eyadati project.

## Frontend

*   **Framework:** Flutter (v3.29.0)
*   **Language:** Dart (v3.8.1)
*   **State Management:** `provider`
*   **UI/UX:**
    *   `google_fonts`: For custom fonts.
    *   `flex_color_scheme`: For creating color schemes.
    *   `table_calendar`: For displaying calendars.
    *   `settings_ui`: For creating settings screens.
    *   `flutter_slidable`: For creating slidable list items.
    *   `sliding_up_panel`: For creating sliding panels.
    *   `marquee`: For creating scrolling text.
*   **Localization:** `easy_localization` (Supporting English, French, and Arabic).

## Backend

*   **Primary Backend:** Firebase
    *   **Authentication:** Firebase Auth
    *   **Database:** Cloud Firestore
    *   **Real-time Communication:** Firebase Cloud Messaging (FCM)
    *   **Crash Reporting:** Firebase Crashlytics
    *   **Analytics:** Firebase Analytics
*   **Secondary Backend:** Supabase

## Key Integrations & Features

*   **Payments:** `chargily_pay`
*   **Location & Maps:**
    *   `geolocator`
    *   `google_maps_url_extractor`
    *   `google_places_flutter`
*   **QR Code:**
    *   `qr_flutter`
    *   `mobile_scanner`
*   **Media:**
    *   `image_picker`
    *   `file_picker`
*   **Calendar Integration:** `add_2_calendar`
*   **Connectivity:** `connectivity_plus`

## Development & Tooling

*   **Linting:** `flutter_lints`
*   **Testing:** `mockito` for generating mock classes.
*   **Build Tool:** `build_runner` for code generation.