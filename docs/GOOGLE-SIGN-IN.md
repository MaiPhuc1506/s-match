# Google Sign-In setup

Use a Google **Web application** OAuth client ID as `GOOGLE_SERVER_CLIENT_ID`
for NestJS and Flutter. Register a separate iOS OAuth client for the active
Runner bundle identifier and pass its ID as `GOOGLE_IOS_CLIENT_ID` to Flutter
(`--dart-define` or `--dart-define-from-file`). Put the reversed iOS client ID
in the ignored `mobile/ios/Flutter/GoogleOAuth.local.xcconfig` as
`GOOGLE_IOS_REVERSED_CLIENT_ID = com.googleusercontent.apps.…`. Android builds
also need an Android OAuth client registered for the application ID and signing
certificate. For a restricted Google consent screen, add the test Google account.

Deploy the additive `GoogleIdentity` migration before enabling Google on that
backend. No new Google account is created when a matching email already exists:
authenticate with the existing account first and use the authorized
`POST /auth/google/link` API with a new Google ID token. A linked account retains
its existing ID, role and profile. Never send client secrets in the Flutter build.
The current app session uses the same in-memory access/refresh flow as password
login; backend refresh sessions and Google identity bindings survive relogin.
