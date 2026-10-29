> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# MAP_PERFORMANCE_AUDIT_AND_OPTIMIZATION.md

Updated: 2026-10-14

## Scope

This note records the safe Map performance audit and optimization pass.

The task did not change Map business rules, Place API, Trip API, Route API,
database schema, Flyway migrations, Auth, or Cloudinary behavior.

## Runtime Checks

Device available during this pass:

- Android device: `SM N770F`
- ADB reverse: `tcp:8081 -> tcp:8081`

Commands run:

- `flutter analyze --no-fatal-warnings --no-fatal-infos`
- `flutter test`
- `flutter run --profile -d ANDROID_DEVICE_SERIAL --no-resident --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1`
- `flutter run --debug -d ANDROID_DEVICE_SERIAL --no-resident --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1`

Result:

- Analyze completed with existing warning/info issues only.
- Flutter tests passed.
- Profile and debug builds installed and launched on the device.
- The launched app was at the login screen, so a logged-in manual pan/zoom
  profile trace could not be completed in this pass.

## Findings

### Not Found

The Map camera callback did not directly trigger repeated business API calls:

- no repeated `/places` calls from camera movement;
- no repeated `/trips` calls from camera movement;
- no repeated `/locations` calls from camera movement;
- no repeated `/routes` calls from camera movement.

Marker recreation was already guarded:

- Explore marker rendering is gated by marker mode and zoom bucket.
- Member marker rendering is gated by visibility and zoom bucket.
- Route rendering is signature based and not directly tied to every camera
  movement.

### Root Causes Addressed

1. `onCameraChanged` could call full `setState()` while panning/zooming.
   This rebuilt the whole map screen stack during high-frequency camera events.

2. Selected Place card tracking could call `pixelForCoordinate()` and update
   Flutter UI for nearly every camera event.

3. Explore zoom updates were requested from every camera event even though
   marker recreation was internally bucketed.

4. The current-user pulse animation updated a Mapbox annotation every 40 ms
   while active. That is visually useful, but too aggressive for a screen that
   also handles gestures, route layers, markers, and overlays.

5. After the first optimization, user testing still showed jank with
   `Choreographer skipped frames` and GC pauses. The remaining likely source was
   still app-side annotation churn: Explore markers, member markers, current
   user marker sizing, selected-card screen projection, and pulse updates could
   still run near the gesture window.

## Changes Made

### Map Screen

File:

- `lib/features/map/screens/map_screen.dart`

Changes:

- Replaced camera-driven full-screen rebuilds with small `ValueNotifier`
  updates for camera chrome such as compass state.
- Moved selected Place card positioning to a dedicated `ValueNotifier`.
- Throttled selected-card `pixelForCoordinate()` updates and now resyncs it
  after Mapbox reports map idle instead of continuously during pan/zoom.
- Ignored selected-card movement smaller than 4 px.
- Moved Explore/member/current-user zoom refresh to `onMapIdleListener`, so
  marker recreation is not performed while the user is actively panning or
  pinching.
- Wrapped `MapWidget` in a `RepaintBoundary` so Flutter overlay repaints are
  less likely to dirty the native map widget subtree.

### Mapbox Layer Controller

File:

- `lib/features/map/services/mapbox_layer_controller.dart`

Changes:

- Reduced current-user pulse annotation update frequency from 40 ms to 80 ms.
- Kept the pulse behavior; only the native annotation update rate changed.
- Pauses the current-user pulse while the native map camera is moving and
  resumes it after map idle.
- Stops recreating Place/member/current-user annotations just to slightly resize
  them across zoom buckets. Markers now switch only on major visual mode changes.
- Uses the Mapbox style line as the primary route renderer; polyline annotation
  route drawing is now fallback only if the style line cannot be updated.

## Before / After

Before:

- Camera movement could rebuild the full Map screen stack.
- Selected Place card could trigger high-frequency platform calls and UI
  updates.
- Current-user pulse could update native annotations about 25 times per second.
- Explore/member/current-user markers could still be deleted/recreated during
  zoom bucket transitions.
- Route drawing used both a style line and annotation polylines, doubling route
  render work on supported devices.

After:

- Camera movement updates only the small UI pieces that need to move.
- Selected Place card movement is throttled and thresholded.
- Explore zoom changes are applied after map idle.
- Current-user pulse updates about 12.5 times per second.
- Current-user pulse is paused while the map is moving.
- Marker recreation during pinch zoom is greatly reduced.
- Route line uses one primary renderer in the normal supported path.

## Log Interpretation

`E/FrameEvents: updateAcquireFence: Did not find frame` and Mapbox gesture
diagnostics are treated as symptoms or platform/vendor diagnostics unless they
line up with app-side repeated rebuilds, API bursts, marker recreation, or route
redraws.

During this pass, debug logs showed startup skipped frames while the app was on
the login screen. That is not enough evidence to conclude the Map gesture issue
is still present after the optimization.

Follow-up user testing showed improvement but still visible jank. The
`Choreographer skipped frames` plus GC pause logs are treated as stronger
evidence of app-side frame pressure than `FrameEvents` alone. The second pass
therefore targeted object/native annotation churn during gestures.

The next user test reported zoom as much smoother, but panning and marker taps
still felt slightly delayed. The third safe pass therefore targeted tap-time
state work and overlay hit testing without changing Map UX or business flow.

## Verification Status

Verified:

- Flutter analyze completes.
- Flutter tests pass.
- Debug build launches on device.
- Profile build launches on device.
- No schema/API/business contract was changed.
- Second-pass profile APK build/install succeeded on the Android device.
- Third-pass Flutter analyze completed with existing warning/info issues only.
- Third-pass Flutter tests passed.
- Final safe scan Flutter analyze completed with existing warning/info issues
  only.
- Final safe scan Flutter tests passed.

Still needs logged-in device confirmation:

- pan/zoom smoothness on the Map screen;
- marker tap and selected Place card positioning;
- pinned/editing Trip route overlay;
- current-location route overlay;
- long session with current-user pulse active.

## Third-Pass Safe Optimizations

Files:

- `lib/features/map/screens/map_screen.dart`
- `lib/features/map/state/map_state.dart`
- `lib/features/map/services/mapbox_layer_controller.dart`

Changes:

- Marker tap now selects from the already-loaded Place list immediately, so the
  selected card can appear without waiting for `GET /places/{id}`.
- Place detail enrichment now runs shortly after the tap/camera focus starts,
  and is canceled if the user selects another marker.
- Opening the detail screen still loads/enriches full Place detail if needed,
  so the detail page keeps the real data behavior.
- Focus animation is skipped when the camera is already close to the selected
  Place and shortened for normal marker taps.
- Loading/coordinate status pills no longer participate in pointer hit testing,
  reducing accidental gesture competition above the native Mapbox view.

Notes:

- `GestureDetector`, `MultiFingerGesture`, and `FrameEvents` lines can still be
  printed by the native Mapbox/Android stack during real gestures. They are not
  automatically proof of a Flutter bug. The app-side fix is to reduce work done
  during those gesture windows.
- No fallback demo data, hard-coded coordinates, schema change, or business
  rule change was introduced.

## Final Safe Scan

The last pass checked these possible lag sources:

- camera callbacks and full-screen rebuilds;
- Mapbox annotation delete/create paths;
- selected marker tap/update path;
- selected Place card screen-coordinate projection;
- map-idle layer synchronization;
- current-user pulse timing;
- route redraw and Trip route sync;
- overlay widgets that can compete with native map gestures;
- delayed timers that can stack up after repeated taps.

Additional safe changes:

- Debounced `onMapIdle` synchronization so layer updates wait briefly after the
  map settles instead of running on every idle pulse.
- Canceled pending map-idle sync when a new camera movement starts.
- Removed one redundant full `setState()` when clearing a selected Place.
- Converted the coordinate text auto-hide from uncancelable delayed futures to
  a single cancelable timer.
- Delayed selected Place detail enrichment slightly longer so it starts after
  the tap/camera focus window rather than during it.
- Reused the existing selected `PointAnnotation` with `update()` when the marker
  visual type is unchanged, avoiding unnecessary `deleteAll()` + `create()` on
  common same-category marker taps.

Deferred on purpose:

- Replacing all Place annotations with a full GeoJSON/style-layer marker system.
  That may be the next architectural optimization if hundreds/thousands of
  markers are needed, but it changes the marker rendering/tap plumbing and is
  too risky for this safe polish pass.
- Upgrading Mapbox SDK APIs from deprecated listener/camera options. Analyzer
  reports them as deprecations, not runtime errors; changing them is a separate
  compatibility task and should not be mixed into this performance closure.

## Follow-Up If Lag Remains

If user-visible lag remains after this pass, the next step should be a logged-in
profile trace on the Map screen and a focused check of:

- platform channel traffic from Mapbox annotation updates;
- number of active Mapbox annotations/layers;
- image cache behavior for visible Place thumbnails;
- route redraw frequency while a Trip is pinned or edited;
- any backend/network calls while panning.

