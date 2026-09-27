# FrameFuse Manual Test Checklist

## Device Setup
- [ ] Android device running Android 8.0+ (API 26+)
- [ ] Device has front and rear cameras
- [ ] Device has at least 500 MB free storage
- [ ] USB debugging enabled

## Permissions
- [ ] App requests camera permission on first launch
- [ ] App requests microphone permission on first launch
- [ ] App requests storage permission on first launch
- [ ] Denying camera permission shows friendly message with "Grant" and "Open Settings" options
- [ ] Granting permissions after denial re-initializes camera
- [ ] App does NOT request unnecessary permissions

## Camera Preview
- [ ] Camera preview loads within 2 seconds
- [ ] Preview displays at full resolution
- [ ] Portrait (9:16) framing guide visible (coral/pink border)
- [ ] Landscape (16:9) framing guide visible (teal border)
- [ ] Grid overlay toggles on/off
- [ ] Tap-to-focus works (focus point changes)
- [ ] Double-tap toggles zoom/exposure sliders

## Camera Controls
- [ ] Flash cycles: Off → Auto → On → Torch
- [ ] Flash disabled on front camera
- [ ] Camera switch works (front ↔ rear)
- [ ] Grid toggle works
- [ ] Settings button opens settings screen
- [ ] Controls auto-hide during recording

## Photo Capture
- [ ] Shutter button appears white in photo mode
- [ ] Pressing shutter captures photo
- [ ] Processing overlay appears briefly
- [ ] Two files saved: `*_portrait.jpg` and `*_landscape.jpg`
- [ ] Portrait photo is 9:16 aspect ratio
- [ ] Landscape photo is 16:9 aspect ratio
- [ ] Both files appear in FrameFuse/Photos/ directory
- [ ] Review screen opens automatically after capture
- [ ] Success snackbar appears

## Video Recording
- [ ] Mode selector switches to Video
- [ ] Record button appearance changes (red border in video mode)
- [ ] Pressing record starts recording
- [ ] Record button transforms to stop button (rounded square)
- [ ] Recording timer counts up accurately
- [ ] Red dot pulses during recording
- [ ] Pause button pauses recording
- [ ] "PAUSED" label appears when paused
- [ ] Resume continues recording
- [ ] Stopping recording shows processing progress
- [ ] Two files saved: `*_portrait.mp4` and `*_landscape.mp4`
- [ ] Review screen opens after processing

## Review Screen
- [ ] "Recording Complete" title displayed
- [ ] Portrait card shows correct metadata (9:16, platforms)
- [ ] Landscape card shows correct metadata (16:9, platforms)
- [ ] Video playback works (tap to play/pause)
- [ ] Photo preview displays correctly
- [ ] Individual share button works per output
- [ ] "Share Both" button shares both files
- [ ] "Delete" button confirms before deleting
- [ ] Closing review returns to camera

## Gallery
- [ ] Gallery loads all captured media
- [ ] Projects grouped by session (portrait + landscape together)
- [ ] "All" tab shows everything
- [ ] "Photos" tab filters correctly
- [ ] "Videos" tab filters correctly
- [ ] Project card shows dual thumbnails
- [ ] Tapping thumbnail opens review
- [ ] Share action shares both files
- [ ] Delete action removes both files
- [ ] Pull-to-refresh works
- [ ] Empty state shows when no media exists

## Settings
- [ ] Resolution dropdown works (720p, 1080p, 4K)
- [ ] FPS dropdown works (24, 30, 60)
- [ ] Audio toggle works
- [ ] Stabilization toggle works
- [ ] Timer dropdown works
- [ ] Portrait guide toggle works
- [ ] Landscape guide toggle works
- [ ] Grid toggle works
- [ ] Theme switching works (Dark, Light, System)
- [ ] Settings persist across app restart
- [ ] About section shows correct version
- [ ] Licenses page opens

## Lifecycle & Error Handling
- [ ] App backgrounded → camera pauses
- [ ] App resumed → camera resumes
- [ ] Incoming phone call during recording → recording stops gracefully
- [ ] Screen rotation locked to portrait
- [ ] Low storage warning (if testable)
- [ ] Camera used by another app → error message
- [ ] No crash on any action
- [ ] No raw exceptions shown to user

## Performance
- [ ] Camera preview at smooth framerate (30fps)
- [ ] No visible lag during recording
- [ ] 1-minute recording completes without issues
- [ ] 5-minute recording completes without issues
- [ ] Post-processing completes in reasonable time
- [ ] App does not overheat device excessively
- [ ] Memory usage stays reasonable (check via Android Studio profiler)

## File System
- [ ] Files saved to correct directories
- [ ] File naming follows `yyyy-MM-dd_HH-mm-ss_portrait/landscape.ext` format
- [ ] No filename collisions (capture twice rapidly)
- [ ] Master file cleaned up after processing
- [ ] Files visible in system Gallery/Photos app

## Device Compatibility
- [ ] Test on low-end device (2GB RAM)
- [ ] Test on mid-range device (4GB RAM)
- [ ] Test on flagship device (8GB+ RAM)
- [ ] Test on Android 8 (API 26)
- [ ] Test on Android 12 (API 31)
- [ ] Test on Android 13+ (API 33+) — granular media permissions
- [ ] Test on Android 14+ (API 34+)
