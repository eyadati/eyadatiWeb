# Product Definition: Eyadati

## 1. Overview

Eyadati is a Flutter mobile application designed to streamline the management of appointments between users and clinics. It provides a comprehensive platform for booking, managing, and tracking medical appointments, offering distinct functionalities for both patients and healthcare providers (clinics).

## 2. Core Features

### 2.1. Appointment Management
*   **Booking:** Users can discover clinics, view available slots, and book appointments.
*   **Scheduling:** Clinics can manage their availability, set up appointment slots, and view booked appointments.
*   **Notifications:** Integrated Firebase Cloud Messaging (FCM) for reminders and updates.

### 2.2. User & Clinic Profiles
*   **User Accounts:** Patients can register, manage their profiles, and track their appointment history.
*   **Clinic Accounts:** Clinics can register, edit their profiles, manage their services, and view their patient appointments.

### 2.3. Localization
*   Support for multiple languages: English, French, and Arabic, ensuring a broad user base.

### 2.4. Integrations
*   **Authentication:** Firebase Authentication for secure user and clinic logins.
*   **Data Storage:** Cloud Firestore for real-time database capabilities.
*   **Additional Backend:** Supabase integration for extended backend functionalities.
*   **Payment Processing:** Chargily Pay for handling financial transactions (e.g., appointment fees).
*   **Location Services:** Geolocation and map integration for clinic discovery and navigation.
*   **QR Code Functionality:** For potential check-ins or other in-clinic uses.

## 3. Technology Highlights

*   **Frontend:** Flutter (Dart) for cross-platform mobile development.
*   **State Management:** Provider for efficient and scalable state management.
*   **UI/UX:** Utilizes `google_fonts`, `flex_color_scheme` for a modern and customizable user interface, and `table_calendar` for intuitive scheduling.

## 4. Architecture Overview

The application follows a modular architecture, separating concerns into distinct feature directories:
*   `lib/Appointments`: Logic for booking and managing appointments.
*   `lib/clinic`: Clinic-specific features (appointments, profile, registration).
*   `lib/user`: User-specific features (appointments, profile, registration).
*   `lib/FCM`: Firebase Cloud Messaging helper functions.
*   `lib/Themes`: Application-wide theming (light and dark modes).
