# Screenshots

Captured from the iOS Simulator (iPhone 17, iOS 26.4) on the `ios-companion-app` branch.

These exercise the real app, not mockups. Note that Screen Time APIs no-op in the
simulator, so no actual shielding happens — what's verified here is navigation, the
timeline math, config persistence, the `lightsout://` deep link, and the friction flow.

Reaching these screens at all depends on the `targetEnvironment(simulator)` affordances
in `AuthorizationManager` and `OnboardingView`; without them onboarding cannot be
completed without a paid Apple Developer account. See ../../README.md.

| File | Screen |
|------|--------|
| 01-welcome.png | Onboarding step 1 |
| 02-authorization.png | Onboarding step 2 — Screen Time authorization |
| 03-phase-times.png | Onboarding step 4 — phase times |
| 04-dashboard.png | Dashboard, lights-out phase with live countdown |
| 05-settings.png | Settings |
| 06-friction-timer.png | Override sheet, forced-wait timer |
| 07-friction-typing.png | Override sheet, typing wall |
