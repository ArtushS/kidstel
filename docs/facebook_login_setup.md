# Facebook Login (Firebase Auth) setup (Android)

This project implements Facebook sign-in using Firebase Auth + `flutter_facebook_auth`.

> Note: The app is configured to use **web-only** login (`LoginBehavior.webOnly`) so it works on the Android Emulator without the Facebook app installed.

## 1) Fill Android resource placeholders

Edit `android/app/src/main/res/values/strings.xml`:

- `facebook_app_id` = your **numeric** Meta App ID (example: `123456789012345`)
- `facebook_client_token` = your Meta **Client Token**
- `fb_login_protocol_scheme` = `fb<APP_ID>` (example: `fb123456789012345`)

These values are referenced from `android/app/src/main/AndroidManifest.xml`.

## 2) Meta (Facebook) app settings

In **Meta for Developers**:

1. Create an app (Consumer is typically fine for login).
2. Add the **Facebook Login** product.
3. In **Settings → Basic**:
   - Copy **App ID** and **App Secret** (you will need both in Firebase).
   - Copy **Client Token** (used by the native SDK; put it into `strings.xml`).
4. Add platform **Android** and set:
   - Package name: `com.fairycraft.app`
   - Class name: `com.fairycraft.app.MainActivity`
   - Key hashes: add your **debug** key hash (see section 4).

While the Meta app is in **Development** mode, ensure your Facebook account is added as:
- a **Developer**, **Admin**, or **Tester** of the app

Otherwise login can fail with “app not configured” style errors.

## 3) Firebase console settings

In **Firebase Console → Authentication → Sign-in method**:

1. Enable **Facebook** provider.
2. Paste:
   - **App ID**
   - **App Secret**
3. Copy the **OAuth redirect URI** shown by Firebase.

Back in **Meta for Developers → Facebook Login → Settings**:

- Add that URI to **Valid OAuth Redirect URIs**.

## 4) Debug key hash on Windows (no OpenSSL)

Meta requires a “key hash”:

$$\text{keyHash} = \text{base64}(\text{sha1}(\text{DER-certificate-bytes}))$$

Here’s a PowerShell snippet that computes it from the default debug keystore **without OpenSSL**:

- Keystore path: `%USERPROFILE%\.android\debug.keystore`
- Alias: `androiddebugkey`
- Store password: `android`
- Key password: `android`

PowerShell (prints the key hash you paste into Meta):

```powershell
$Keystore = Join-Path $env:USERPROFILE ".android\debug.keystore"
$Alias = "androiddebugkey"
$StorePass = "android"
$KeyPass = "android"

# Export cert as PEM text
$Pem = & keytool -exportcert -alias $Alias -keystore $Keystore -storepass $StorePass -keypass $KeyPass -rfc

# Strip header/footer and decode Base64 → DER bytes
$Base64 = ($Pem -split "`r?`n" | Where-Object {
  $_ -and $_ -notmatch "BEGIN CERTIFICATE" -and $_ -notmatch "END CERTIFICATE"
}) -join ""
$Bytes = [Convert]::FromBase64String($Base64)

# SHA1(DER) then Base64
$Sha1 = [System.Security.Cryptography.SHA1]::Create()
$HashBytes = $Sha1.ComputeHash($Bytes)
[Convert]::ToBase64String($HashBytes)
```

If `keytool` is not found, ensure your JDK `bin` is on PATH.

## 5) Expected behavior / verification

- In the app, tap **Continue with Facebook**.
- A browser/custom tab login should open.
- After successful login, you should return to the app signed in.
- Verify in **Firebase Console → Authentication → Users** that a new user exists with provider `facebook.com`.

## 6) Troubleshooting

- **“Invalid application ID”**: your `facebook_app_id` in `strings.xml` is still a placeholder or incorrect.
- **Stuck on browser / no return to app**: `fb_login_protocol_scheme` must be exactly `fb<APP_ID>` and match Meta/Firebase config.
- **“App not configured”**: app is still in Development mode and your FB account is not added as a tester/developer.
