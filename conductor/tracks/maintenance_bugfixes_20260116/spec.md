# Specification: Application Maintenance, Bug Fixes, and Minor Enhancements

## 1. Overview

This track addresses a collection of identified issues, performance optimizations, and minor feature enhancements across the Eyadati application, focusing on improving stability, user experience, and code maintainability for both clinic and user functionalities.

## 2. Functional Requirements / Bug Fixes / Enhancements

### 2.1. File and Folder Structure Review
*   **FR2.1.1:** Review the current folder structure, particularly for clinic and user files, to improve organization and discoverability of related files.

### 2.2. Clinic Side Improvements
*   **FR2.2.1: Specialty Name Standardization:** Standardize specialty names (e.g., "psychology" to "psychologist") for consistent display and filtering.
*   **FR2.2.2: Subscription Ended Button:** Implement a functional "finish" button related to a "subscription ended" state, providing appropriate user feedback and actions.
*   **FR2.2.3: Dark Mode Color Correction:** Address and fix any identified issues with dark mode colors on the clinic side to ensure proper display and readability.
*   **FR2.2.4: Clinic Pause Feature:** Implement a toggle switch in clinic settings to allow clinics to pause their profile, making them invisible to users.
*   **FR2.2.5: Account Deletion:** Implement a robust account deletion feature in clinic settings, ensuring all associated data (user favorites, appointments, clinic data) is removed with a confirmation dialogue.
*   **FR2.2.6: Terms of Service & Privacy Policy:** Implement the display of Terms of Service and Privacy Policy in clinic settings.
*   **FR2.2.7: Clinic Avatar Display:** Implement the display of the clinic's profile picture (`picUrl` from Firestore) at the top of clinic settings.

### 2.3. User Side Improvements
*   **FR2.3.1: Navigation Item Display:** Fix `_buildNavItem` where number 1 always shows nothing, even if a working widget is assigned.
*   **FR2.3.2: App Start Data Fetching:** Modify app startup to fetch data directly from the server, using cache only when opening the clinics list for improved data freshness.
*   **FR2.3.3: Favorite Clinics Display:** Ensure favorite clinics are correctly displayed by fetching their information directly from Firestore, rather than relying on cached or unknown data. Use user UID to fetch clinic info.
*   **FR2.3.4: Clinic Filter Correction:** Review and fix behavior errors in the clinic filter functionality on the user side.
*   **FR2.3.5: Slot Generation Fix:** Address and fix issues with slot generation that cause overlaps with breaks and missing slots. Implement a method to store all available slots in a list and then remove conflicting ones.
*   **FR2.3.6: Appointment Confirmation Display:** Fix the issue where appointments are not showing immediately after confirmation until a hot restart.

### 2.4. General Improvements
*   **FR2.4.1: Theming Standardization:** Standardize the application's theme to "teal blue," ensuring all widgets and the overall UI adhere to best practices.
*   **FR2.4.2: Backend Optimization Review:** Review Firebase and Supabase functions to optimize consumption and reduce costs.
*   **FR2.4.3: Project Flow Analysis:** Read project files to estimate potential bugs, missing implementations, and analyze the overall flow of data.

## 3. Non-Functional Requirements

*   **NFR1: Performance:** Changes should not negatively impact application performance.
*   **NFR2: Testability:** New logic and bug fixes must be covered by appropriate tests.
*   **NFR3: Maintainability:** Code changes should align with existing conventions and improve overall maintainability.

## 4. Out of Scope

*   Major architectural overhauls not directly related to the listed tasks.
*   Implementation of entirely new, unlisted features.
