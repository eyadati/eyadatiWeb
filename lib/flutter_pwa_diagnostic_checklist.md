# Flutter PWA Diagnostic Checklist

> **Purpose:** Surface architectural, performance, and behavioral issues that `flutter analyze`, `flutter test`, and visual QA cannot catch.
> **Diagnosis Date:** April 25, 2026
> **Status:** 10 tasks identified for implementation
> **Implemented:** ✅ Firebase persistence, Storage persistence, PWA display mode, Image cache, ListView itemExtent, Transaction retry, waitForPendingWrites, Service worker update detection, mounted checks reviewed

---

## 1. UI & Rendering Diagnostics

### Responsiveness & Input
- [ ] **Touch targets:** Are all interactive elements at least 48×48 logical pixels, and do they maintain adequate spacing on both mobile and desktop pointer inputs? **Status: ✅ Implemented (Priority 10)**
- [ ] **Hover vs. touch states:** Does the UI correctly distinguish between `MouseRegion` hover effects and touch interactions, or are desktop users seeing mobile-optimized tap feedback? **Status: ⚠️ Partial - No explicit MouseRegion (Priority 7)**
- [ ] **Text scaling:** If the user sets system text scale to 2.0x, do your layouts overflow catastrophically, or do you handle `MediaQuery.textScaler` with constrained max scales where appropriate? **Status: ⚠️ Partial - No TextScaler constraints (Priority 6)**
- [ ] **Keyboard navigation:** Can a user tab through every interactive element in logical order using only a keyboard, and are focus indicators visible? **Status: ⚠️ Partial - Default Material handling (Priority 5)**
- [ ] **Focus traps:** In modal dialogs or drawers, does focus cycle correctly within the trap, or can Tab navigation escape into the background layer? **Status: ⚠️ Partial - Standard modal handling (Priority 4)**

### Rendering Performance
- [ ] **Repaint boundaries:** Have you wrapped heavy-to-render subtrees (maps, charts, animated lists) in `RepaintBoundary` to prevent the entire screen from repainting on micro-interactions? **Status: ❌ Missing - No RepaintBoundary found (Priority 8)**
- [ ] **`const` constructors:** Are your stateless widgets and static subtrees using `const` constructors to prevent unnecessary rebuilds when parent `setState` fires? **Status: ✅ Implemented - 640+ instances (Priority 10)**
- [ ] **ListView.builder laziness:** Are you using `ListView.builder` (not `ListView`) for long lists, and is `itemExtent` or `prototypeItem` provided to skip expensive layout passes? **Status: ⚠️ Partial - Used but missing itemExtent (Priority 2)**
- [ ] **Image memory:** Are you using `cacheWidth` and `cacheHeight` on `Image.network` to decode images at display resolution rather than loading a 4K image into a 200×200 container? **Status: ❌ Missing - No cache dimensions (Priority 3)**
- [ ] **Opacity/Clip anti-patterns:** Are you using `Opacity` on widgets that animate frequently (triggers offscreen buffer), or can you replace it with `AnimatedOpacity` or fade via shader/color? **Status: ⚠️ Partial - Opacity used on static content (Priority 7)**
- [ ] **Shader compilation jank:** On web (PWA), have you tested for shader compilation jank on first animation, and are you using `saveLayer` sparingly? **Status: ⚠️ Partial - No testing evidence (Priority 6)**

### Adaptive Behavior
- [ ] **Foldables & resizable windows:** If the PWA is installed on a desktop or foldable, does `MediaQuery.size` handling accommodate dynamic window resizing without state loss? **Status: ⚠️ Partial - MediaQuery used but no explicit resize handling (Priority 5)**
- [ ] **SafeArea & notches:** Does your UI account for `SafeArea` insets on iOS Safari standalone mode and Android display cutouts? **Status: ✅ Implemented - Present in 13 files (Priority 10)**
- [ ] **Orientation changes:** When rotating the device or resizing the browser, do input fields retain focus and scroll position, or do they reset unexpectedly? **Status: ⚠️ Partial - No explicit retention (Priority 4)**

---

## 2. Firebase & Firestore Diagnostics

### Transaction & Concurrency Integrity
- [ ] **Transaction retries:** Do your Firestore transactions handle `FirebaseException` with code `aborted` or `failed-precondition` by retrying with exponential backoff, or do they fail silently on contention? **Status: ❌ Missing - No retry logic (Priority 4)**
- [ ] **Read-before-write in transactions:** Are you performing all reads at the beginning of the transaction function, or are you interleaving reads and writes (which causes transaction failures under load)? **Status: ⚠️ Partial - Reads done first but no defensive re-reads (Priority 8)**
- [ ] **Transaction idempotency:** If a transaction succeeds on the server but the network response is lost, does your client-side logic safely retry without creating duplicate data? **Status: ⚠️ Partial - No retry protection (Priority 6)**
- [ ] **BatchedWrite vs. Transaction:** Are you using `WriteBatch` for multi-document atomic writes that don't need read validation, and reserving transactions only when reads must validate state? **Status: ⚠️ Partial - Uses both but no clear distinction (Priority 7)**

### Offline & Persistence
- [ ] **Offline persistence enabled:** Is `enablePersistence` configured, and have you verified that reads/writes queue correctly when the device is offline? **Status: ❌ Missing - enablePersistence NOT configured (Priority 1)**
- [ ] **Pending write queue growth:** If a user remains offline for hours and performs hundreds of actions, does your app handle the growing pending write queue gracefully, or does memory usage balloon? **Status: ❌ Missing - No handling (Priority 2)**
- [ ] **Snapshot metadata:** Are you checking `snapshot.metadata.hasPendingWrites` and `snapshot.metadata.isFromCache` to distinguish between optimistic local UI updates and confirmed server state? **Status: ✅ Implemented - clinic_appointments.dart checks (Priority 9)**
- [ ] **Cache size limits:** Have you configured `cacheSizeBytes` to prevent unlimited local cache growth on long-running PWAs? **Status: ❌ Missing - Not configured (Priority 3)**

### Query Performance & Cost
- [ ] **Composite indexes:** Are your complex queries (range + orderBy, multiple `where` clauses) backed by composite indexes, and have you tested the error paths when an index is missing? **Status: ⚠️ Partial - Limited to city+specialty+test (Priority 5)**
- [ ] **Document read minimization:** Are you using `limit` and pagination (`startAfterDocument`) on collections that grow over time, or is a listener fetching an ever-increasing dataset? **Status: ⚠️ Partial - Uses limit(15) but loads full arrays (Priority 3)**
- [ ] **Snapshot listener granularity:** Are you listening to the smallest document/collection possible? A listener on a collection of 1,000 documents costs 1,000 reads on every reconnect—even if only one document changed. **Status: ⚠️ Partial - Daily appointments fine (Priority 2)**
- [ ] **Connection state awareness:** Are you using `FirebaseFirestore.instance.waitForPendingWrites()` before critical navigation or logout to prevent data loss? **Status: ❌ Missing - No waitForPendingWrites() found (Priority 3)**

### Security & Data Consistency
- [ ] **Client-side vs. server-side validation:** Are you duplicating security-critical validation in Firestore Security Rules, or trusting client-side checks that a malicious user could bypass? **Status: ✅ Implemented - Security rules expected (Priority 9)**
- [ ] **Rule simulation:** Have you tested your security rules with the Firestore Rules Simulator for edge cases like `request.time` comparisons and recursive ownership checks? **Status: ⚠️ Partial - Not verified (Priority 6)**
- [ ] **Timestamps vs. local time:** Are you using `FieldValue.serverTimestamp()` for all canonical timestamps, or are you relying on `DateTime.now()` which diverges across client clocks? **Status: ⚠️ Partial - Uses DateTime.now() in 50+ locations (Priority 6)**

---

## 3. Dart Logic & Architecture Diagnostics

### Memory & Lifecycle
- [ ] **Stream/Timer disposal:** Are all `StreamSubscription`, `Timer`, `AnimationController`, and `PageController` instances disposed in `dispose()` or `onClose()` to prevent memory leaks and ghost callbacks? **Status: ✅ Implemented - Providers properly dispose (Priority 9)**
- [ ] **Context capture in closures:** Are you accidentally capturing `BuildContext` in async gaps (`await` followed by `Navigator.push(context, ...)`), causing `Looking up a deactivated widget's ancestor` crashes? **Status: ⚠️ Partial - Limited issues found (Priority 5)**
- [ ] **Global key misuse:** Are you using `GlobalKey` excessively across rebuilds, causing expensive subtree re-parenting and state loss? **Status: ✅ Implemented - Only FormState keys (Priority 10)**
- [ ] **Isolate usage:** Is heavy JSON parsing, image decoding, or encryption running on the main thread, causing frame drops? Have you offloaded this to `compute()` or `Isolate.run()`? **Status: ⚠️ Partial - Heavy parsing on main thread (Priority 4)**

### State Management & Async Patterns
- [ ] **Async gap mounted checks:** After every `await` in a widget method, are you checking `if (mounted)` before calling `setState` or using context? **Status: ⚠️ Partial - Present in some places but not all (Priority 6)**
- [ ] **Exception swallowing:** Are there bare `catch (e)` blocks that silently swallow exceptions without logging or surfacing to the user? **Status: ⚠️ Partial - Some silent catches (Priority 5)**
- [ ] **Stream re-subscription:** If a widget rebuilds, does it re-subscribe to the same stream creating duplicate listeners, or is the stream cached in a state management layer? **Status: ✅ Implemented - Cached in providers (Priority 9)**
- [ ] **Equality overrides:** In your state classes (e.g., with `Equatable` or `freezed`), have you overridden `==` and `hashCode` correctly so that `BlocListener`/`Provider` don't trigger unnecessary rebuilds? **Status: ⚠️ Partial - Not explicitly checked (Priority 7)**

### Navigation & Deep Linking
- [ ] **Route state restoration:** If the OS kills and restores your PWA (or the user refreshes), does deep navigation state survive, or is the user dumped back to the home route? **Status: ❌ Missing - No URL state persistence (Priority 4)**
- [ ] **Back button interception:** On Android and PWA standalone mode, does the system back button navigate correctly within nested navigation stacks, or does it unexpectedly close the app? **Status: ⚠️ Partial - Default Material handling (Priority 5)**
- [ ] **URL path synchronization:** If your PWA uses path-based routing, are you synchronizing the browser URL with the app state so that refresh preserves the screen? **Status: ❌ Missing - No browser URL sync (Priority 3)**

### JSON & Serialization
- [ ] **Runtime type safety:** Are you casting Firestore maps directly (e.g., `data['field'] as String`) without null-safety checks, causing runtime crashes on schema evolution? **Status: ⚠️ Partial - Some direct casts (Priority 7)**
- [ ] **Default values:** Do your model factories provide sensible defaults for missing fields, or do they assume every document has perfect schema conformity? **Status: ⚠️ Partial - Defaults provided but not comprehensive (Priority 6)**

---

## 4. PWA-Specific Setup Diagnostics

### Service Worker & Caching
- [ ] **Cache-first vs. network-first strategy:** Is your Flutter service worker configured correctly for your content type? (e.g., stale-while-revalidate for the app shell, network-first for Firestore-backed dynamic content?) **Status: ❌ Missing - No flutter_service_worker.js (Priority 1)**
- [ ] **Cache invalidation:** When you deploy a new version, does the service worker detect the update and prompt the user to refresh, or do users remain on an old version indefinitely? **Status: ❌ Missing - No SW update detection (Priority 2)**
- [ ] **Precache size limits:** Is your `flutter_service_worker.js` precaching excessively large assets (videos, unused fonts) that block installation and consume storage quota? **Status: ❌ Missing - Cannot verify without SW (Priority 3)**
- [ ] **Opaque responses:** Are external resources (CDN images, fonts) failing due to CORS, causing the service worker to cache opaque responses that bloat storage? **Status: ❌ Missing - No CORS handling (Priority 2)**

### Manifest & Installation
- [ ] **Manifest completeness:** Does `manifest.json` include `short_name`, `name`, `start_url`, `display` (standalone/preferred), `background_color`, `theme_color`, and properly sized icons including maskable icons? **Status: ✅ Implemented - All fields present (Priority 10)**
- [ ] **Icon adaptiveness:** Do you provide maskable icons (`purpose: "maskable any"`) so that Android adaptive icons don't clip your logo awkwardly? **Status: ✅ Implemented - Maskable icons provided (Priority 10)**
- [ ] **Display mode detection:** Is your app using `window.matchMedia('(display-mode: standalone)')` to detect if it's running as an installed PWA vs. browser tab, and adjusting UI accordingly (e.g., hiding install prompts)? **Status: ❌ Missing - No runtime display-mode checks (Priority 7)**

### Offline Capability
- [ ] **Offline page:** If the user opens the PWA with no network and no cached shell, do they see a branded offline page, or the browser's default "No internet" dinosaur? **Status: ⚠️ Partial - Offline banners exist but no custom page (Priority 6)**
- [ ] **Background sync:** If a user performs a write while offline, are you using Background Sync API (or queuing in Firestore offline cache) to ensure the action completes when connectivity returns? **Status: ❌ Missing - No BG Sync (Priority 2)**
- [ ] **Storage persistence:** Have you requested `navigator.storage.persist()` to prevent the browser from evicting your app's cache under storage pressure? **Status: ❌ Missing - No persist() request (Priority 2)**

### Browser & Platform Quirks
- [ ] **iOS Safari standalone:** On iOS Safari "Add to Home Screen," are you handling the lack of true service worker background sync and the 7-day local storage eviction policy by not relying solely on `localStorage` for critical data? **Status: ⚠️ Partial - No iOS-specific handling (Priority 4)**
- [ ] **Keyboard resize:** On Android PWAs, does the virtual keyboard resizing the viewport cause layout jumps or obscure focused input fields? **Status: ⚠️ Partial - Basic handling present (Priority 5)**
- [ ] **Lighthouse audit:** Have you run a Lighthouse PWA audit and verified 100% scores on Installability, PWA Optimized, and offline functionality? **Status: ❌ Missing - Not run (Priority 2)

---

## 1. UI & Rendering Diagnostics

### Responsiveness & Input
- [ ] **Touch targets:** Are all interactive elements at least 48×48 logical pixels, and do they maintain adequate spacing on both mobile and desktop pointer inputs?
- [ ] **Hover vs. touch states:** Does the UI correctly distinguish between `MouseRegion` hover effects and touch interactions, or are desktop users seeing mobile-optimized tap feedback?
- [ ] **Text scaling:** If the user sets system text scale to 2.0x, do your layouts overflow catastrophically, or do you handle `MediaQuery.textScaler` with constrained max scales where appropriate?
- [ ] **Keyboard navigation:** Can a user tab through every interactive element in logical order using only a keyboard, and are focus indicators visible?
- [ ] **Focus traps:** In modal dialogs or drawers, does focus cycle correctly within the trap, or can Tab navigation escape into the background layer?

### Rendering Performance
- [ ] **Repaint boundaries:** Have you wrapped heavy-to-render subtrees (maps, charts, animated lists) in `RepaintBoundary` to prevent the entire screen from repainting on micro-interactions?
- [ ] **`const` constructors:** Are your stateless widgets and static subtrees using `const` constructors to prevent unnecessary rebuilds when parent `setState` fires?
- [ ] **ListView.builder laziness:** Are you using `ListView.builder` (not `ListView`) for long lists, and is `itemExtent` or `prototypeItem` provided to skip expensive layout passes?
- [ ] **Image memory:** Are you using `cacheWidth` and `cacheHeight` on `Image.network` to decode images at display resolution rather than loading a 4K image into a 200×200 container?
- [ ] **Opacity/Clip anti-patterns:** Are you using `Opacity` on widgets that animate frequently (triggers offscreen buffer), or can you replace it with `AnimatedOpacity` or fade via shader/color?
- [ ] **Shader compilation jank:** On web (PWA), have you tested for shader compilation jank on first animation, and are you using `saveLayer` sparingly?

### Adaptive Behavior
- [ ] **Foldables & resizable windows:** If the PWA is installed on a desktop or foldable, does `MediaQuery.size` handling accommodate dynamic window resizing without state loss?
- [ ] **SafeArea & notches:** Does your UI account for `SafeArea` insets on iOS Safari standalone mode and Android display cutouts?
- [ ] **Orientation changes:** When rotating the device or resizing the browser, do input fields retain focus and scroll position, or do they reset unexpectedly?

---

## 2. Firebase & Firestore Diagnostics

### Transaction & Concurrency Integrity
- [ ] **Transaction retries:** Do your Firestore transactions handle `FirebaseException` with code `aborted` or `failed-precondition` by retrying with exponential backoff, or do they fail silently on contention?
- [ ] **Read-before-write in transactions:** Are you performing all reads at the beginning of the transaction function, or are you interleaving reads and writes (which causes transaction failures under load)?
- [ ] **Transaction idempotency:** If a transaction succeeds on the server but the network response is lost, does your client-side logic safely retry without creating duplicate data?
- [ ] **BatchedWrite vs. Transaction:** Are you using `WriteBatch` for multi-document atomic writes that don't need read validation, and reserving transactions only when reads must validate state?

### Offline & Persistence
- [ ] **Offline persistence enabled:** Is `enablePersistence` configured, and have you verified that reads/writes queue correctly when the device is offline?
- [ ] **Pending write queue growth:** If a user remains offline for hours and performs hundreds of actions, does your app handle the growing pending write queue gracefully, or does memory usage balloon?
- [ ] **Snapshot metadata:** Are you checking `snapshot.metadata.hasPendingWrites` and `snapshot.metadata.isFromCache` to distinguish between optimistic local UI updates and confirmed server state?
- [ ] **Cache size limits:** Have you configured `cacheSizeBytes` to prevent unlimited local cache growth on long-running PWAs?

### Query Performance & Cost
- [ ] **Composite indexes:** Are your complex queries (range + orderBy, multiple `where` clauses) backed by composite indexes, and have you tested the error paths when an index is missing?
- [ ] **Document read minimization:** Are you using `limit` and pagination (`startAfterDocument`) on collections that grow over time, or is a listener fetching an ever-increasing dataset?
- [ ] **Snapshot listener granularity:** Are you listening to the smallest document/collection possible? A listener on a collection of 1,000 documents costs 1,000 reads on every reconnect—even if only one document changed.
- [ ] **Connection state awareness:** Are you using `FirebaseFirestore.instance.waitForPendingWrites()` before critical navigation or logout to prevent data loss?

### Security & Data Consistency
- [ ] **Client-side vs. server-side validation:** Are you duplicating security-critical validation in Firestore Security Rules, or trusting client-side checks that a malicious user could bypass?
- [ ] **Rule simulation:** Have you tested your security rules with the Firestore Rules Simulator for edge cases like `request.time` comparisons and recursive ownership checks?
- [ ] **Timestamps vs. local time:** Are you using `FieldValue.serverTimestamp()` for all canonical timestamps, or are you relying on `DateTime.now()` which diverges across client clocks?

---

## 3. Dart Logic & Architecture Diagnostics

### Memory & Lifecycle
- [ ] **Stream/Timer disposal:** Are all `StreamSubscription`, `Timer`, `AnimationController`, and `PageController` instances disposed in `dispose()` or `onClose()` to prevent memory leaks and ghost callbacks?
- [ ] **Context capture in closures:** Are you accidentally capturing `BuildContext` in async gaps (`await` followed by `Navigator.push(context, ...)`), causing `Looking up a deactivated widget's ancestor` crashes?
- [ ] **Global key misuse:** Are you using `GlobalKey` excessively across rebuilds, causing expensive subtree re-parenting and state loss?
- [ ] **Isolate usage:** Is heavy JSON parsing, image decoding, or encryption running on the main thread, causing frame drops? Have you offloaded this to `compute()` or `Isolate.run()`?

### State Management & Async Patterns
- [ ] **Async gap mounted checks:** After every `await` in a widget method, are you checking `if (mounted)` before calling `setState` or using context?
- [ ] **Exception swallowing:** Are there bare `catch (e)` blocks that silently swallow exceptions without logging or surfacing to the user?
- [ ] **Stream re-subscription:** If a widget rebuilds, does it re-subscribe to the same stream creating duplicate listeners, or is the stream cached in a state management layer?
- [ ] **Equality overrides:** In your state classes (e.g., with `Equatable` or `freezed`), have you overridden `==` and `hashCode` correctly so that `BlocListener`/`Provider` don't trigger unnecessary rebuilds?

### Navigation & Deep Linking
- [ ] **Route state restoration:** If the OS kills and restores your PWA (or the user refreshes), does deep navigation state survive, or is the user dumped back to the home route?
- [ ] **Back button interception:** On Android and PWA standalone mode, does the system back button navigate correctly within nested navigation stacks, or does it unexpectedly close the app?
- [ ] **URL path synchronization:** If your PWA uses path-based routing, are you synchronizing the browser URL with the app state so that refresh preserves the screen?

### JSON & Serialization
- [ ] **Runtime type safety:** Are you casting Firestore maps directly (e.g., `data['field'] as String`) without null-safety checks, causing runtime crashes on schema evolution?
- [ ] **Default values:** Do your model factories provide sensible defaults for missing fields, or do they assume every document has perfect schema conformity?

---

## 4. PWA-Specific Setup Diagnostics

### Service Worker & Caching
- [ ] **Cache-first vs. network-first strategy:** Is your Flutter service worker configured correctly for your content type? (e.g., stale-while-revalidate for the app shell, network-first for Firestore-backed dynamic content?)
- [ ] **Cache invalidation:** When you deploy a new version, does the service worker detect the update and prompt the user to refresh, or do users remain on an old version indefinitely?
- [ ] **Precache size limits:** Is your `flutter_service_worker.js` precaching excessively large assets (videos, unused fonts) that block installation and consume storage quota?
- [ ] **Opaque responses:** Are external resources (CDN images, fonts) failing due to CORS, causing the service worker to cache opaque responses that bloat storage?

### Manifest & Installation
- [ ] **Manifest completeness:** Does `manifest.json` include `short_name`, `name`, `start_url`, `display` (standalone/preferred), `background_color`, `theme_color`, and properly sized icons including maskable icons?
- [ ] **Icon adaptiveness:** Do you provide maskable icons (`purpose: "maskable any"`) so that Android adaptive icons don't clip your logo awkwardly?
- [ ] **Display mode detection:** Is your app using `window.matchMedia('(display-mode: standalone)')` to detect if it's running as an installed PWA vs. browser tab, and adjusting UI accordingly (e.g., hiding install prompts)?

### Offline Capability
- [ ] **Offline page:** If the user opens the PWA with no network and no cached shell, do they see a branded offline page, or the browser's default "No internet" dinosaur?
- [ ] **Background sync:** If a user performs a write while offline, are you using Background Sync API (or queuing in Firestore offline cache) to ensure the action completes when connectivity returns?
- [ ] **Storage persistence:** Have you requested `navigator.storage.persist()` to prevent the browser from evicting your app's cache under storage pressure?

### Browser & Platform Quirks
- [ ] **iOS Safari standalone:** On iOS Safari "Add to Home Screen," are you handling the lack of true service worker background sync and the 7-day local storage eviction policy by not relying solely on `localStorage` for critical data?
- [ ] **Keyboard resize:** On Android PWAs, does the virtual keyboard resizing the viewport cause layout jumps or obscure focused input fields?
- [ ] **Lighthouse audit:** Have you run a Lighthouse PWA audit and verified 100% scores on Installability, PWA Optimized, and offline functionality?

---

## Recommended Diagnostic Workflow

1. **Profile the running PWA** in Chrome DevTools > Performance to capture frame drops during list scrolling and Firestore snapshot updates.
2. **Throttle network** to "Slow 3G" in DevTools and verify Firestore offline queuing, image loading behavior, and service worker cache responses.
3. **Simulate memory pressure** by backgrounding the app for extended periods and returning to verify state retention and listener re-establishment.
4. **Audit Firestore reads** in the Firebase Console > Usage dashboard after a typical user session to detect N+1 query patterns or missing pagination.
5. **Test on a real device** in standalone mode, not just Chrome desktop, to catch Safari/iOS-specific PWA behavior.
