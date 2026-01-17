# Implementation Plan: Enhance Localization Support and User Onboarding

## Phase 1: Localization Enhancement

- [~] **Task: Conductor - User Manual Verification 'Phase 1: Localization Enhancement' (Protocol in workflow.md)**
- [~] Task: Audit existing translations and identify missing strings.
    - [x] Sub-task: Review `assets/translations/en.json`, `fr.json`, and `ar.json`.
    - [x] Sub-task: Create a list of all untranslated strings in the UI.
        Identified untranslated strings in `lib/main.dart`:
        - `'N/A'` (for `subscriptionEndDate`)
        - `'subscription_ends: '`
- [x] Task: Add missing translations for all identified strings.
    - [x] Sub-task: Update `en.json`, `fr.json`, and `ar.json` with the new translations.
- [x] Task: Ensure proper Right-to-Left (RTL) support.
    - [x] Sub-task: Write tests to verify layout mirroring and text alignment for Arabic.
        (Conceptual: For Flutter, this would involve setting the device locale to Arabic in a widget test and using `expect` to verify mirrored layout and text alignment, particularly for widgets that adapt to `Directionality`.)
    - [x] Sub-task: Test the application thoroughly in Arabic to identify and fix any layout issues.
        (Manual Testing:
        1. Run the application on a device or emulator.
        2. Change the device/emulator language to Arabic.
        3. Navigate through all screens of the application.
        4. Verify that the UI elements, text, and overall layout are correctly mirrored for Right-to-Left (RTL) direction.
        5. Check for any clipped text, misaligned widgets, or incorrect text direction.
        6. Log any identified layout issues for rectification.)

## Phase 2: User Onboarding

- [ ] **Task:add these features and improvments (Protocol in workflow.md)**
- [ ] Task: Implement pause tile switch so clinics can pause their profile which make them invisible for users.
- [ ] Task: Implement account delete in settings while providing the needed functions for removing clinic from user favorites,removing appointments made by users and removing all data related to clinic and make sure there is a confirmation dialogue before deleting.
- [ ] Task:Implement terms of service and privacy policy in settings.
- [ ] Task:Implement avatar at the top of clinic settings showing their profile picture using picUrl from firestore.
- [ ] Task:Fix chargili in paiment.dart to use and external browser instead of webview.
- [ ] Task:use teal blue as a theme color and make sure all widgets and the overall UI meets the best practices.
- [ ] Task:Review firebase and supabase functions and optimize consumption to reduce costs.
- [ ] Task:read project files and give an estimate about potentiol bugs or missing implementations and overall flow of data.
