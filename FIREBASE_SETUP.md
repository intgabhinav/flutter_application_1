# Firebase Setup Instructions

To complete the Firebase setup for this Flutter application, follow these steps:

## 1. Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" and follow the setup wizard
3. Give your project a name and follow the prompts to create the project

## 2. Register Your Flutter App with Firebase

### For Android:

1. In the Firebase console, click on your project
2. Click the Android icon (🤖) to add an Android app to your Firebase project
3. Enter your app's package name (found in `android/app/build.gradle` under `applicationId`)
4. Enter a nickname for your app (optional)
5. Enter your app's SHA-1 signing certificate (optional for now, but required for some Firebase services)
6. Click "Register app"
7. Download the `google-services.json` file
8. Move the file into your Flutter project's `android/app` directory

### For iOS:

1. In the Firebase console, click on your project
2. Click the iOS icon (🍎) to add an iOS app to your Firebase project
3. Enter your app's bundle ID (found in Xcode under the "General" tab of your app target settings)
4. Enter a nickname for your app (optional)
5. Enter your app's App Store ID (optional)
6. Click "Register app"
7. Download the `GoogleService-Info.plist` file
8. Move the file into your Flutter project using Xcode (Right-click on the Runner directory, select "Add Files to 'Runner'", and select the downloaded file)

## 3. Add Firebase SDK to Your Flutter App

The necessary dependencies have already been added to your `pubspec.yaml` file:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  provider: ^6.1.1
```

Run `flutter pub get` to install these dependencies.

## 4. Initialize Firebase in Your App

Use the FlutterFire CLI to generate the Firebase configuration file:

1. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Run the FlutterFire configure command:
   ```bash
   flutterfire configure --project=your-firebase-project-id
   ```

3. This will generate a `firebase_options.dart` file in your `lib` directory. Replace the placeholder file with this generated file.

## 5. Update Your Code

Update the Firebase initialization in `main.dart` to use the generated options:

```dart
import 'firebase_options.dart';

// ...

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 6. Enable Authentication in Firebase Console

1. In the Firebase console, go to "Authentication"
2. Click "Get started"
3. Enable the "Email/Password" sign-in method
4. Enable the "Google" sign-in method
5. Save your changes

## 7. Configure Google Sign-In

### For Android:

1. In the Firebase console, go to "Authentication" > "Sign-in method" > "Google"
2. Make sure your SHA-1 certificate fingerprint is added to your Firebase project
   - You can get your SHA-1 by running: `cd android && ./gradlew signingReport`
3. In your `android/app/build.gradle` file, make sure your `minSdkVersion` is at least 21

### For iOS:

1. In your Xcode project, open the `Info.plist` file
2. Add a URL scheme for Google Sign-In:
   - Add a new key: `CFBundleURLTypes`
   - Add a dictionary to this key with the following values:
     - `CFBundleTypeRole`: `Editor`
     - `CFBundleURLSchemes`: Array with one item: `com.googleusercontent.apps.YOUR-CLIENT-ID`
     - Replace `YOUR-CLIENT-ID` with the client ID from your `GoogleService-Info.plist` file

## 8. Test Your App

Run your app and test the authentication flow. You should be able to:
- Register a new user
- Sign in with registered credentials
- Sign out

If you encounter any issues, check the console logs for error messages.