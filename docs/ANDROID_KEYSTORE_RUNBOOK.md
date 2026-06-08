# Android Release Keystore Runbook (MT-144 / STORE-10)

Creating and safeguarding the upload keystore that signs Play Store builds. This
is both a **launch gate** (Play won't accept a debug-signed build) and a
**bus-factor Critical** (lose the keystore and you can never ship an update to
the same listing) — so the last step (back it up) matters as much as the first.

The Gradle wiring is already done: `android/app/build.gradle.kts` loads
`android/key.properties` if present and signs `release` with it, else falls back
to debug signing. You only need to create the keystore + the properties file.

## Prerequisites
- A JDK installed (`keytool` ships with it). Check: `keytool -help`.
  Flutter's bundled JDK works too — `flutter doctor -v` shows its path.

## 1. Generate the keystore
From a terminal, in `android/app/`:

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It prompts for:
- a **keystore password** and a **key password** (can be the same; write both down),
- your name/org (any reasonable values — these appear in the cert, not to users).

This writes `android/app/upload-keystore.jks`.

## 2. Create key.properties
Copy the template and fill it in:

```bash
cp android/key.properties.example android/key.properties
```

Set `storePassword`, `keyPassword`, `keyAlias` (`upload`), and `storeFile`
(`upload-keystore.jks` if you placed it in `android/app/`, or an absolute path).

## 3. Confirm both are gitignored
Neither file may ever be committed (this repo is public):

```bash
git check-ignore android/key.properties android/app/upload-keystore.jks
```

Both paths should print (= ignored). If either doesn't, add it to `.gitignore`
before doing anything else.

## 4. Build and verify it's release-signed
```bash
flutter build appbundle --release
```

The build log should show it using the `release` signing config (not "debug").
The output `.aab` (`build/app/outputs/bundle/release/`) is what you upload to the
Play Console.

## 5. BACK IT UP — do not skip (bus-factor Critical)
The keystore is **not recoverable** if lost. Immediately:
- Store the `.jks` file as a **Document** item in the continuity vault
  (`RECOVERY.md` §2d), and
- Store the `storePassword` / `keyPassword` / `keyAlias` alongside it.

Without this, a lost laptop = no more Play Store updates for this app, ever.

## Note on Google Play App Signing
Play's default **App Signing** lets Google hold the final *app signing key* while
you keep this *upload key*. If you enrol, a lost upload key can be reset by
Google support — but **still back this up**; relying on a support ticket during a
crisis is not a plan. This keystore is your upload key regardless.
