# Implementation Plan: Enhance Localization Support and User Onboarding

## Phase 1: Localization Enhancement

- [ ] **Task: Conductor - User Manual Verification 'Phase 1: Localization Enhancement' (Protocol in workflow.md)**
- [ ] Task: Audit existing translations and identify missing strings.
    - [ ] Sub-task: Review `assets/translations/en.json`, `fr.json`, and `ar.json`.
    - [ ] Sub-task: Create a list of all untranslated strings in the UI.
- [ ] Task: Add missing translations for all identified strings.
    - [ ] Sub-task: Update `en.json`, `fr.json`, and `ar.json` with the new translations.
- [ ] Task: Ensure proper Right-to-Left (RTL) support.
    - [ ] Sub-task: Write tests to verify layout mirroring and text alignment for Arabic.
    - [ ] Sub-task: Test the application thoroughly in Arabic to identify and fix any layout issues.

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
