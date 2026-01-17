# Implementation Plan: Application Maintenance, Bug Fixes, and Minor Enhancements

## Phase 1: General Maintenance and Code Review

- [~] **Task: Conductor - User Manual Verification 'Phase 1: General Maintenance and Code Review' (Protocol in workflow.md)**
- [x] Task: Review folder and filter where clinic files and user files are located for better organization.
    - [x] Sub-task: Identify current file organization patterns.
    - [x] Sub-task: Propose improvements for file grouping and naming.
        Proposed Improvements:
        General:
        *   Feature-based Grouping: Organize files more explicitly by feature within clinic and user directories, e.g., lib/clinic/auth, lib/clinic/profile, lib/clinic/appointments.
        *   Clearer Naming: Ensure file names accurately reflect their content and responsibility. Avoid generic names like utils.dart without further context if possible.
        *   Consistency: Standardize naming conventions across the project (e.g., camelCase for files, consistent use of _ for private parts).
        Specific to `lib/clinic`:
        *   `clinicAuth.dart`: Could be `auth/clinic_auth_service.dart` or similar.
        *   `clinicEditeProfile.dart`: Could be `profile/clinic_profile_editor.dart`.
        *   `clinicHome.dart`: Could be `home/clinic_home_screen.dart`.
        *   `clinicRegisterUi.dart` and `clinicRegisterUi_widgets.dart`: Consider consolidating or renaming to `registration/clinic_registration_screen.dart` and `registration/clinic_registration_widgets.dart`.
        *   `clinicSettingsPage.dart`: Could be `settings/clinic_settings_screen.dart`.
        *   `clinic_appointments.dart`: Could be `appointments/clinic_appointments_manager.dart`.
        *   `clinic_firestore.dart`: Could be `data/clinic_firestore_service.dart` or `repositories/clinic_repository.dart`.
        Specific to `lib/user`:
        *   `userAuth.dart`: Could be `auth/user_auth_service.dart`.
        *   `userEditProfile.dart`: Could be `profile/user_profile_editor.dart`.
        *   `UserHome.dart`: Could be `home/user_home_screen.dart`.
        *   `userQrScannerPage.dart`: Could be `scanner/user_qr_scanner_screen.dart`.
        *   `userRegistrationUi.dart`: Could be `registration/user_registration_screen.dart`.
        *   `userSettingsPage.dart`: Could be `settings/user_settings_screen.dart`.
        *   `userAppointments.dart` and `user_appointments.dart`: These need to be reviewed for redundancy and consolidated/renamed to `appointments/user_appointments_manager.dart` or similar.
        *   `user_firestore.dart`: Could be `data/user_firestore_service.dart` or `repositories/user_repository.dart`.
- [x] Task: Review Firebase and Supabase functions and optimize consumption to reduce costs.
    - [x] Sub-task: Analyze current function usage and billing.
        (Analysis Process for Human User:
        1. Access Firebase Console: Navigate to the Firebase project dashboard.
        2. Review Usage Dashboards: Examine Cloud Firestore, Cloud Functions, and Firebase Authentication usage reports to identify high-volume operations.
        3. Check Firebase Billing: Review the billing section to understand cost drivers.
        4. Access Supabase Dashboard: Navigate to the Supabase project dashboard.
        5. Review Usage Metrics: Examine database queries, edge function invocations, and storage usage.
        6. Check Supabase Billing: Review the billing section for Supabase cost breakdown.
        7. Identify specific services or queries contributing most to usage/cost.)
    - [x] Sub-task: Identify areas for optimization (e.g., query efficiency, trigger frequency).
        Identified Areas for Optimization:
        *   Firestore Query Optimization: Ensure all queries have appropriate indexes. Avoid large document reads if only specific fields are needed (use `select`). Implement pagination for large lists. Consider denormalizing data for frequently accessed, aggregated views to reduce reads.
        *   Firebase Functions / Supabase Edge Functions: Minimize function invocations by debouncing or throttling triggers. Optimize function logic for efficiency to reduce execution time and memory consumption. Ensure proper error handling to prevent retries and unnecessary resource usage. Consider cold start optimization techniques for frequently used functions.
        *   Firebase Authentication: Review authentication flows to ensure only necessary operations are performed.
        *   Firebase Storage: Optimize image/file sizes. Implement caching strategies.
        *   Supabase Database: Review SQL queries for efficiency (e.g., `EXPLAIN ANALYZE`). Ensure appropriate database indexes are in place. Optimize table schemas for read/write patterns. Consider using Row Level Security (RLS) effectively to reduce complex query logic in client.
- [~] Task: Read project files and give an estimate about potential bugs or missing implementations and overall flow of data.
    - [x] Sub-task: Document data flow between frontend, Firebase, and Supabase.
        High-Level Data Flow Documentation:
        *   Authentication (Firebase Auth): Handled by Firebase SDK directly, authenticating users/clinics via lib/clinic/clinicAuth.dart, lib/user/userAuth.dart, lib/main.dart. User/Clinic UIDs used in Firestore documents.
        *   Clinic Data (Firestore): Managed via lib/clinic/clinic_firestore.dart (addClinic, updateClinic, getAvailableClinics) and displayed/edited in UI files like lib/clinic/clinicEditeProfile.dart, lib/clinic/clinicRegisterUi.dart, lib/clinic/clinicSettingsPage.dart, lib/clinic/clinicHome.dart. Data stored in FirebaseFirestore.instance.collection("clinics").
        *   User Data (Firestore): Managed via lib/user/user_firestore.dart (assumed CRUD) and displayed/edited in UI files like lib/user/userEditProfile.dart, lib/user/userRegistrationUi.dart, lib/user/userSettingsPage.dart, lib/user/UserHome.dart. Data stored in FirebaseFirestore.instance.collection("users").
        *   Appointments (Firestore): Handled via lib/Appointments/booking_logic.dart, lib/Appointments/clinicsList.dart, lib/Appointments/slotsUi.dart, lib/clinic/clinic_appointments.dart, lib/user/userAppointments.dart. Nested under /clinics/{clinicId}/appointments and /users/{userId}/appointments.
        *   Firebase Cloud Messaging (FCM): Initialized in lib/main.dart; handlers in lib/FCM/notificationsService.dart, lib/FCM/fcm_helper_functions.dart. FCM tokens stored with clinic data.
        *   Supabase: Initialized in lib/main.dart. SupabaseClient is present in ClinicFirestore but not actively used in provided methods, suggesting use for other services (Edge Functions, other DB interactions) not directly visible in client-side code. Needs further investigation of supabase/ directory.
    - [x] Sub-task: Identify potential error points or missing error handling.
        Identified Potential Error Points / Missing Error Handling:
        1.  Network Connectivity: While `no_internet_connection` is handled, robust feedback and retry mechanisms are needed across all network operations. Consistent, user-facing error messages and graceful degradation are crucial.
        2.  Firebase Authentication Errors: Generic messages for `FirebaseAuthException`. Specific error codes (e.g., `user-not-found`, `wrong-password`) should map to user-friendly messages. Token expiry handling.
        3.  Firestore Operations Errors: Need to gracefully handle `PERMISSION_DENIED` errors. Missing document checks (`clinic_data_not_found`, `no_user_found`). Potential race conditions in concurrent modifications. Explicit strategies for offline data sync conflicts.
        4.  Supabase Interactions: Unclear usage, but any interactions require robust error handling for API failures, network issues, and invalid input.
        5.  Input Validation: Ensure server-side validation mirrors client-side.
        6.  Asynchronous Operations: Missing loading indicators, potential UI race conditions.
        7.  Push Notifications (FCM): Handling of payload parsing errors, null FCM tokens, and appropriate messages for permission statuses.
        8.  Third-Party Integrations: Clear, user-friendly error messages and retry options for `chargily_pay`. Proper permissions handling for `geolocator`, `mobile_scanner`, `image_picker`, `file_picker`.
        9.  Subscription Logic: Careful handling of `subscriptionStartDate`, `subscriptionEndDate`, `paused` to prevent unauthorized access or incorrect feature availability.

## Phase 2: Clinic Side Bug Fixes and Enhancements

- [ ] **Task: Conductor - User Manual Verification 'Phase 2: Clinic Side Bug Fixes and Enhancements' (Protocol in workflow.md)**
- [ ] Task: Change specialty names (e.g., "psychology" to "psychologist").
    - [ ] Sub-task: Identify all instances of specialty names in code and data.
    - [ ] Sub-task: Implement a mapping or direct renaming strategy.
- [ ] Task: Implement "finish" button related to subscription ended state.
    - [ ] Sub-task: Design UI for the button and its interaction flow.
    - [ ] Sub-task: Implement logic to handle subscription ended state and associated actions.
- [ ] Task: Fix dark mode colors on the clinic side.
    - [ ] Sub-task: Identify incorrect dark mode color usages.
    - [ ] Sub-task: Adjust color values to ensure proper contrast and theme adherence.
- [ ] Task: Implement pause tile switch for clinics.
    - [ ] Sub-task: Design UI for the pause switch in clinic settings.
    - [ ] Sub-task: Implement backend logic to store and retrieve clinic pause status.
- [ ] Task: Implement account deletion in clinic settings.
    - [ ] Sub-task: Design confirmation dialogue and deletion flow.
    - [ ] Sub-task: Implement functions to remove clinic data from user favorites, appointments, and all related data.
- [ ] Task: Implement terms of service and privacy policy in clinic settings.
    - [ ] Sub-task: Design UI for displaying legal documents.
    - [ ] Sub-task: Integrate content for Terms of Service and Privacy Policy.
- [ ] Task: Implement avatar display at the top of clinic settings.
    - [ ] Sub-task: Fetch `picUrl` from Firestore.
    - [ ] Sub-task: Display the clinic's profile picture using `picUrl`.

## Phase 3: User Side Bug Fixes and Enhancements

- [ ] **Task: Conductor - User Manual Verification 'Phase 3: User Side Bug Fixes and Enhancements' (Protocol in workflow.md)**
- [ ] Task: Fix `_buildNavItem` display issue (number 1 always shows nothing).
    - [ ] Sub-task: Debug the `_buildNavItem` logic and identify the cause of the display error.
    - [ ] Sub-task: Implement fix to ensure all navigation items display correctly.
- [ ] Task: Modify app start to fetch data from server, using cache only for clinics list.
    - [ ] Sub-task: Adjust data fetching strategy on app startup.
    - [ ] Sub-task: Implement logic for server-first data fetching and cache fallback for clinics list.
- [ ] Task: Fix favorite clinics not showing correctly.
    - [ ] Sub-task: Fetch favorite clinics from Firestore, not cache, using user UID.
    - [ ] Sub-task: Correctly display fetched clinic information.
- [ ] Task: Review and fix clinic filter behavior errors.
    - [ ] Sub-task: Debug clinic filter functionality.
    - [ ] Sub-task: Implement fixes to ensure correct filtering behavior.
- [ ] Task: Fix slots generation (overlaps with breaks, missing slots).
    - [ ] Sub-task: Debug slot generation logic.
    - [ ] Sub-task: Implement method to store all available slots and remove conflicting ones.
- [ ] Task: Fix appointments not showing immediately after confirmation.
    - [ ] Sub-task: Debug appointment display logic after confirmation.
    - [ ] Sub-task: Implement real-time update or refresh mechanism.

## Phase 4: Theming and External Integrations

- [ ] **Task: Conductor - User Manual Verification 'Phase 4: Theming and External Integrations' (Protocol in workflow.md)**
- [ ] Task: Use teal blue as a theme color and ensure all widgets and overall UI meets best practices.
    - [ ] Sub-task: Define teal blue color palette in `ThemeData`.
    - [ ] Sub-task: Apply theme consistently across all UI widgets.
    - [ ] Sub-task: Review UI for best practices adherence (e.g., contrast, responsiveness).
- [ ] Task: Fix Chargily in `paiment.dart` to use an external browser instead of webview.
    - [ ] Sub-task: Identify current `paiment.dart` implementation for Chargily.
    - [ ] Sub-task: Replace webview with external browser integration (e.g., using `url_launcher`).
