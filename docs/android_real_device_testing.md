# Testing on a real Android device

## Prereqs

- Android Studio installed (for drivers + SDK).
- A USB cable that supports data.

## Device setup

1) Enable Developer options:
   - Settings → About phone → tap “Build number” 7 times
2) Enable USB debugging:
   - Settings → Developer options → “USB debugging”
3) (Optional) Default USB configuration:
   - Set to “File transfer”/“MTP” to avoid charge-only mode.

## Verify ADB sees the phone

- Run `flutter devices` and confirm your phone appears.
- If it shows as “unauthorized”, accept the RSA fingerprint prompt on the phone.

## Run the app

- `flutter run -d <deviceId>`

## Common issues

- **No devices found**: install OEM USB driver (Windows), try a different cable/USB port.
- **Unauthorized**: revoke USB debugging authorizations and reconnect.
- **App installs but crashes**: check `flutter run` logs; then `flutter analyze` and `flutter test`.

## Notes specific to KidsDom

- Firebase configuration must be present (already committed for Android via `android/app/google-services.json`).
- If you use App Check, debug builds may need debug tokens depending on backend config.
