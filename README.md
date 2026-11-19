# Scripture Library

Scripture Library is a Flutter app for browsing, finding and reading Hindu scriptures. The bundled library opens without a Firebase project. It includes seven links to full texts and a seven-verse Bhagavad Gītā sample in standard Roman transliteration and English. The English renderings were prepared for the sample and await editorial review before a public release.

## Run the app

Use Flutter 3.47 or later with Dart 3.13 or later.

```sh
flutter pub get
flutter run -d chrome
```

Use `flutter devices` to select an Android emulator or an iOS simulator. iOS builds require macOS and Xcode. The device stores the last passage and text size locally.

## Connect Firestore

1. [Follow the Firebase Flutter setup guide](https://firebase.google.com/docs/flutter/setup) to register the target app in your Firebase project. Create a Cloud Firestore database. The Android and iOS project files use development application IDs. Confirm them in the platform build settings before registering.
2. Copy `firebase.local.example.json` to `firebase.local.json` and use the registered app's Firebase configuration values for that platform.
3. Deploy the included rules and single-field index exemption to that Firebase project.

```sh
firebase deploy --only firestore:rules,firestore:indexes --project YOUR_PROJECT_ID
flutter run -d chrome --dart-define-from-file=firebase.local.json
```

The published Firestore catalog replaces the bundled sample catalog when the server responds. The bundled catalog is available when Firestore is unconfigured or unavailable. Clients can query published books and open the currently published edition. Catalog changes use an administrator account.

## Publish a book

The catalog exported from the supplied spreadsheet is in `catalog/master_catalog.json`. Its 688 rows are candidates for edition research. The app uses the seven verified reading entries in `assets/launch_library.json` until Firestore is connected. An external reading link needs a direct URL to an edition that readers can open.

Use the launch manifest as the template for a publishable book. Keep its existing catalog ID when switching from a link to a hosted edition. Assign a new edition ID whenever you revise its content. Record the source, translator and redistribution terms for both text layers in your editorial records and include any required credit in the manifest. Each passage needs a stable reference, its Roman transliteration and its English translation. Split a long chapter into numbered sections if needed.

The publisher writes sections first and changes the catalog document only after the edition is complete. An existing edition can be published again safely with the same data. Check the manifest locally before applying it with authorized Application Default Credentials.

```sh
python tool/publish_library.py --manifest assets/launch_library.json
python -m pip install google-cloud-firestore
python tool/publish_library.py --manifest assets/launch_library.json \
  --project YOUR_PROJECT_ID --apply
```

The same publisher supports the Firestore emulator when `FIRESTORE_EMULATOR_HOST` is set. Firebase client settings and administrator credentials serve different purposes. Keep administrator credentials outside the Flutter project.

```text
books/{catalogId}
  editions/{editionId}
    sections/{sectionId}
```

To re-export a revised spreadsheet, install `openpyxl` and run `python tool/import_catalog.py path/to/catalog.xlsx catalog/master_catalog.json`.

## Checks

```sh
flutter analyze
flutter test
python tool/publish_library.py
```

The bundled Libre Baskerville font is provided under its included SIL Open Font License.
