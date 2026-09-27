# FrameFuse — One take. Both formats.

FrameFuse is an Android camera app for creators. Record once and get a
**9:16** (TikTok / Reels / Shorts) and a **16:9** (YouTube) video from the
same take, with no re-shooting and no manual cropping.

Everything happens on the device. There is no account, no analytics and no
network access.

## Features

- **Onboarding**: welcome, "how often do you shoot twice?", pitch,
  permissions, then a first-take hint over the record button.
- **Dual live preview**: the 9:16 and 16:9 previews are center crops of the
  same camera stream, identical to what gets exported. There are two layouts,
  stacked or picture-in-picture.
- **Capture**: video (with pause/resume) and photo. Quick toggles for HD/FHD/4K
  and 24/30/60 fps, the torch, lens switch, 1×/2× zoom chips, pinch-to-zoom,
  tap-to-focus, an adjustments sheet (exposure, zoom, grid, sound) and a
  recording-time-left estimate.
- **Projects and takes**: takes are filed as *Project / Scene / Take 00N*.
  Takes can be marked as favourites, and there's a library screen.
- **Review**: one player drives both crops so they are always in sync. You
  get a trim bar with a filmstrip, delete, share, and **Save & Export**.
- **Export**: AndroidX Media3 Transformer renders center-cropped, trimmed
  H.264 files. They're saved to `Movies/FrameFuse` (photos go to
  `Pictures/FrameFuse`) through MediaStore, with no storage permission on
  Android 10+.
- **Device safety**: a thermal warning pill, with auto-stop and save when the
  phone is critically hot. Recording also stops and saves when storage is low
  or the app is backgrounded.
- **Locked "Coming Soon" features** (crown): Teleprompter, Screen light and
  Front/Back dual camera.

## Architecture

Flutter with Riverpod (`StateNotifier`), organized as feature-first clean
layers:

```
lib/
  core/        constants, permissions, platform bridge (native_media_service), theme
  features/
    onboarding/  first-run flow
    camera/      CameraService (camera plugin), CameraNotifier, capture screen
    recording/   RecordingService (master clip), DualOutputProcessor, review screen
    projects/    Project/Take model, JSON LibraryStore, LibraryNotifier, project sheet
    gallery/     library screen
    settings/    SharedPreferences settings
  shared/      brand widgets (logo, crown, pills), models
android/app/src/main/kotlin/com/framefuse/app/
  NativeBridge.kt     method and event channels
  VideoExporter.kt    Media3 Transformer crop + trim, CropMath
  MediaTools.kt       photo crop (EXIF-aware), MediaStore export, thumbnails,
                      free space, thermal stream
```

Recording captures one master file. Cropping and trimming happen at export
time, so a take is ready to review as soon as you stop recording.

## Build and run

```bash
flutter pub get
flutter test
flutter run                       # debug on a connected device
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
```

To produce a publishable release, create `android/key.properties`:

```
storeFile=/absolute/path/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without it, release builds are signed with the debug key and are for local
testing only.

Emulator note: on software-GPU emulators Impeller may render a black screen.
Use `flutter run --no-enable-impeller`. Real devices are unaffected.
