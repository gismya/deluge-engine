# Which GUI toolkit for the deluge-engine app?

Research for [#16](https://github.com/gismya/deluge-engine/issues/16), part of the map [#15](https://github.com/gismya/deluge-engine/issues/15). Researched 2026-11-24 against official docs, licences, package repositories and source code. Versions are the latest ones on that date.

## Answer

**Recommendation: Qt 6 with Qt Quick (QML for the screens, C++ for the logic), on Qt 6.12 LTS.**

**Runner-up: Flutter 3.50.** It is the better choice if unattended agent testing matters more than native macOS controls. Its test tooling is the strongest of the four, but it draws every control itself.

Why Qt Quick:

1. **It feels the most native on macOS of the four.** The Qt Quick Controls macOS style is the default on macOS, and its controls are "drawn run-time using native frameworks" ([macOS style][qt-macos-style]). `MenuBar` has been a real macOS menu bar since Qt 6.8 ([MenuBar][qt-menubar]), and `FolderDialog`, which the v1 "choose a card folder" screen needs, opens the native macOS dialog ([FolderDialog][qt-folderdialog]). Flutter, Slint and JUCE draw their own controls.
2. **It runs on Android and every desktop from one QML codebase.** On Android the default style is Material ([styles][qt-styles]).
3. **The GUI and the Engine share one language.** The GUI's backend layer is C++, like the Engine, so the protocol's message types and framing code can be one C++ library that both processes link. With Flutter the protocol needs a second implementation in Dart, or code generation for both sides.
4. **Agents can test it headless, though not as easily as Flutter.** Qt Quick Test runs QML `TestCase`s under `-platform offscreen`, with `mouseClick`, `keyClick` and `grabImage` ([Qt Quick Test][qt-quicktest], [TestCase][qt-testcase]).
5. **Its licence fits GPL-3.0.** Qt Quick Controls is LGPLv3 or GPLv2 ([Qt Quick Controls][qt-controls]), and Homebrew's `qt` formula is LGPL-3.0 / GPL-3.0 ([formula][brew-qt]).
6. **C++ MIDI libraries work in the same process.** RtMidi 6.1.0 (MIT, 2026-10-15) has CoreMIDI and an `ANDROID_AMIDI` backend. In any case, the real Deluge should sit behind a backend process that speaks the protocol, so the toolkit mostly doesn't touch MIDI. See *MIDI and sysex* below.

The ranking isn't close at the top: Qt leads on criterion 1 and Flutter leads on criterion 3. If the user ranks those two the other way round, the answer becomes Flutter, and the protocol and process facts below still apply.

## Scorecard

Higher is better. 3 is strong, 2 is workable, 1 is weak. The scores are judgements based on the evidence in the sections below.

| Criterion | Qt 6.12 Quick | Flutter 3.50 | Slint 1.19 | JUCE 9 |
|---|---|---|---|---|
| 1. Native feel on macOS | **3**: native-drawn controls, menu bar, dialogs | 2: own drawing; native menu bar and dialogs; macOS widgets only from a third-party package | 1–2: `cupertino` style is emulated; native menu bar | 1: own LookAndFeel |
| 2. Android and other desktops | 3 | **3** | 2: Android first and Rust first | 2 |
| 3. Agent build and test | 2: Qt Quick Test offscreen, `grabImage`; Qt install is a CI step | **3**: `flutter test` headless widget and golden tests, `integration_test` on macOS, an official MCP server | 2–3: headless testing backend and an MCP server with screenshots, but the test crate is internal and not semver | 1: unit tests only |
| 4. Engine process and IPC | **3**: `QProcess`, `QLocalSocket`, a shared C++ protocol library; Android services documented | 2: `Process.start` and sockets; protocol reimplemented in Dart | 2 | 3: `ChildProcessCoordinator` with ping and restart |
| 5. Licence with GPL-3.0 | 3: LGPLv3 / GPL | 3: BSD-3-Clause | 3: GPLv3 option | 2: AGPLv3 only (or paid) |
| 6. USB MIDI / sysex later | 3: RtMidi or libremidi in C++ | 2: `flutter_midi_command` (sysex bugs in its history) | 2: C++ or Rust libraries | **3**: built-in MIDI on macOS and Android |

## Findings by criterion

### 1. Native feel on macOS

- **Qt Quick.** The macOS style is the default on macOS ([styles][qt-styles]), its controls are "drawn run-time using native frameworks", and it has existed since Qt 6.0. Limits: BusyIndicator, DelayButton, PageIndicator, RangeSlider, Switch, TabBar and Tumbler fall back to Fusion. The style can't be customised, and its look can change between minor Qt versions ([macOS style][qt-macos-style]). Since Qt 6.8, `MenuBar` and its menus are native on macOS ([MenuBar][qt-menubar]). `FolderDialog` is native on macOS ([FolderDialog][qt-folderdialog]). Qt Widgets would look even more native, but Qt's Android path is Qt Quick ([Android getting started][qt-android]), so the cross-platform choice is QML.
- **Flutter.** Flutter draws every widget itself, and since 3.47 it renders through Impeller by default on macOS ([Impeller][fl-impeller]). The menu bar is native: `PlatformMenuBar` "uses the platform's native APIs to construct and render a menu", with built-in support on macOS only ([PlatformMenuBar][fl-menubar]). The folder picker is native: `file_selector` 1.1.0 (flutter.dev) has `getDirectoryPath` on macOS and Android ([file_selector][pub-file-selector]). Flutter's docs suggest the Cupertino widgets or the third-party `macos_ui` package for a macOS look ([building macOS apps][fl-macos-build]). `macos_ui` 2.2.2 (MIT) was last published on 2025-10-19, so it hasn't had a release in 13 months ([pub.dev][pub-macos-ui]). Native views can be embedded with `AppKitView`, but "gesture support isn't yet available on macOS" ([macOS platform views][fl-platform-views]).
- **Slint.** The `native` style resolves to `cupertino` on macOS, which "emulates the style used by macOS". The `qt` style renders through Qt, so it needs Qt installed ([Slint styles][slint-styles]). Menus are native: the changelog lists a native macOS menu bar, a native `ContextMenuArea` on macOS (1.16), and `MenuItem.role` for the application menu (1.19) ([CHANGELOG][slint-changelog]).
- **JUCE.** JUCE draws its controls through `LookAndFeel` classes such as `LookAndFeel_V4` ([LookAndFeel_V4][juce-lnf]). It looks the same everywhere, which is right for a plugin and wrong for this criterion. Its WebView UI option (added in JUCE 8, with an npm package in 9.0.1, [releases][juce-releases]) is a web view, which the user ruled out.

### 2. Android and other desktops

- **Qt.** Android, Windows and Linux are supported, and the Qt 6.12 Android guide uses Qt Quick throughout ([Android getting started][qt-android]).
- **Flutter.** Android, iOS, Windows, Linux and web all come from one codebase. On Android, Impeller is the default from API 29 ([Impeller][fl-impeller]).
- **Slint.** The Android docs cover Rust only: an `android_main` in a `cdylib` crate, the `backend-android-activity-06` feature, and a `NativeActivity` ([Slint Android][slint-android]). The 1.19 C++ changelog notes that "Android builds default to the Fluent style, like Rust", which suggests C++ on Android exists, but the docs don't describe it ([CHANGELOG][slint-changelog]).
- **JUCE.** Supports Android, and 9.0.6 (2026-11-19) fixed "multiple Android font loading and IME issues" ([releases][juce-releases]).

### 3. Agents building and testing it unattended

GitHub's `macos-latest` runner is macOS 26 on arm64. It ships CMake 4.5, Rust 1.100, JDK 21 and the Android SDK with NDK 27 and 29. It doesn't ship Flutter or Qt ([runner image][gh-runner]).

- **Flutter.**
  - **Headless widget tests:** `flutter test` runs them. The test docs describe a simplified environment rather than a device ([testing overview][fl-testing]).
  - **Golden tests:** built in through `matchesGoldenFile`, with `flutter test --update-goldens` to regenerate them. Caveat: tests use the Ahem font by default, and custom fonts "may render differently across different platforms, or between different versions of Flutter", so goldens must be produced on one pinned platform, the macOS runner ([matchesGoldenFile][fl-golden]).
  - **Full-app tests:** `integration_test` runs the whole app on the macOS desktop with `flutter test integration_test`. It can't touch native UI such as permission dialogs; for those the docs point to `patrol` (4.12.0, 2026-11-24) ([integration tests][fl-integration]).
  - **MCP server:** the official Dart and Flutter MCP server (`dart mcp-server`, marked "experimental") has tools for `run_tests`, `launch_app`, `widget_inspector`, `flutter_driver_command`, `hot_reload` and `get_runtime_errors`, so an agent can drive a running app ([dart_mcp_server README][dart-mcp]).
  - **CI setup:** `subosito/flutter-action` v2.23.0 installs Flutter.
  - **Agent familiarity:** the corpus of Flutter code agents have seen is the largest of the four (an informed judgement, not a measurement).
- **Qt.**
  - **Headless UI tests:** Qt Quick Test runs `tst_*.qml` files through `QUICK_TEST_MAIN`, and `-platform offscreen` hides the window ([Qt Quick Test][qt-quicktest]). `TestCase` has `mouseClick`, `keyClick`, `touchEvent` and `grabImage`. Its result has `pixel()`, `equals()` and `save()`, which is enough for golden comparisons, but there is no built-in update-goldens flow ([TestCase][qt-testcase]).
  - **C++ tests:** QTest covers the C++ side.
  - **Installing Qt in CI:** the official online installer needs a Qt Account login ([installer page][qt-installer]), so CI must use `jurplel/install-qt-action` v4.5.0 (2026-10-25, wrapping aqtinstall) or Homebrew's `qt` 6.12.0.
  - **Build cost:** builds are C++ and CMake, slower than Flutter's.
  - **No end-to-end driver:** I found no free equivalent of Flutter's MCP server or flutter_driver for Qt. Agents would drive the app through Qt Quick Test on the whole `Main.qml`.
- **Slint.** The testing backend "simulates a windowing system without requiring one", with `ElementHandle` queries by accessible label or id, `single_click` and mocked time, from both Rust and C++ (`slint-testing.h`). It also has an embedded MCP server (`--features slint/mcp`, `SLINT_MCP_PORT`, `SLINT_BACKEND=headless`) that lets agents take screenshots, click and type. But the crate is "internal", "should not be used directly", and must be pinned with `=x.y.z` because it isn't semver ([testing README][slint-testing]).
- **JUCE.** It has a `UnitTest` framework. I found no headless widget-test, golden or scripted-UI tooling in its docs.

### 4. Starting and talking to the Engine process

Every toolkit is constrained the same way by the platforms:

- **macOS.**
  - **Bundling:** the Engine binary ships inside the `.app` bundle, and the GUI launches it as a child process.
  - **App Sandbox:** if the app is sandboxed, Apple's guidance for an embedded helper is that it carries only `com.apple.security.app-sandbox` and `com.apple.security.inherit`. Such a helper can't then be run from Terminal ([Apple DTS forum answers][apple-forum-helper]).
  - **Flutter's default:** Flutter's macOS template turns App Sandbox on by default ([building macOS apps][fl-macos-build]). Either turn it off (the app isn't headed for the Mac App Store) or sign the Engine with the inherit entitlement. That choice belongs to the packaging and signing open question in the map.
- **Android.**
  - **No separate executable:** an app targeting API 29 or later "cannot invoke `execve()` directly on files within the app's home directory", and apps "should load only the binary code that's embedded within an app's APK file" ([Android 10 behaviour changes][android-10]). The practical shape is therefore the Engine built as a `.so` inside the APK, loaded by a `Service` that is declared with `android:process=":engine"`.
  - **Separate process:** a process name starting with `:` creates "a new process, private to the application" ([service element][android-service]). A firmware freeze then kills only that process, and the app rebinds to restart it. That matches the map's decision that a freeze restarts only the Engine. This part is plain Kotlin or Java whatever the GUI toolkit.

Per toolkit:

- **Qt.**
  - **macOS:** `QProcess` starts the Engine, and its `finished(exitCode, exitStatus)` signal reports `CrashExit`, which tells the GUI to restart it ([QProcess][qt-qprocess]). Talk over the child's stdin and stdout, or over `QLocalSocket`, a Unix domain socket ([QLocalSocket][qt-qlocalsocket]).
  - **Not iOS:** `QProcess` "is not supported on VxWorks, iOS, tvOS, or watchOS" ([QProcess][qt-qprocess]). iOS isn't a target.
  - **Android:** Qt documents services in a separate process (`android:process=":qt_service"`). Native calls between processes aren't possible, so the app and the service communicate through `QAndroidBinder`, Qt Remote Objects or broadcasts ([Android services][qt-android-services]). The Engine service doesn't need Qt at all. A plain `Service` that loads the Engine `.so` and opens a socket is enough.
- **Flutter.**
  - **macOS:** `Process.start` gives the child's `stdin`, `stdout` and `stderr` as streams, and it wants an absolute path to the executable ([Process.start][dart-process]). `dart:io` sockets accept `InternetAddressType.unix` addresses given as file paths ([InternetAddress][dart-inetaddr]).
  - **Android:** the Engine service lives in the Flutter project's `android/` Gradle module, in Kotlin. The Dart side reaches Kotlin through platform channels or Pigeon (30.0.4) ([platform channels][fl-channels]). It could also connect straight to the service's Unix socket from Dart.
- **JUCE.** `ChildProcessCoordinator` launches a worker, pings it, and calls `handleConnectionLost()` when the worker dies ([ChildProcessCoordinator][juce-coordinator]). That is exactly the restart-on-freeze pattern, but it requires `ChildProcessWorker`, and so AGPL JUCE code, inside the Engine. JUCE's POSIX `ChildProcess` uses `fork` and `execvp` on Android too ([juce_SharedCode_posix.h][juce-posix]), so Android's exec rules still apply.
- **Slint.** It has no process API of its own. A C++ or Rust app uses the standard library or POSIX.

### 5. Licence fit with GPL-3.0

- **Qt.**
  - **Licence:** Qt Quick Controls is LGPLv3 or GPLv2 ([Qt Quick Controls][qt-controls]). Some Qt libraries are GPL-only, which a GPL-3.0 project may use ([LGPL obligations][qt-lgpl]). Qt Remote Objects is LGPLv3 or GPLv2 ([Qt Remote Objects][qt-remoteobjects]).
  - **LTS caveat:** later 6.8 LTS patch releases are commercial only, for example "Commercial LTS Qt 6.8.9" on 2026-09-16 ([Qt releases][qt-releases]). Open-source users should therefore follow the newest minor release rather than an old LTS.
- **Flutter.** BSD-3-Clause ([LICENSE][fl-license]).
- **Slint.** Offered under GPLv3, a royalty-free licence (which requires attribution), or a commercial licence ([LICENSE.md][slint-license]).
- **JUCE.** The modules are "dual-licensed under the AGPLv3 and the commercial JUCE licence" ([LICENSE.md][juce-license]), and JUCE 9 keeps that. GPLv3 §13 permits combining with AGPLv3 code, but the AGPL network-interaction terms then apply to the JUCE part (repo `LICENSE`, §13). This works, but it's the least clean fit of the four.

All four are fine to distribute with a GPL-3.0 Engine. The GUI and the Engine are separate programs talking over a protocol anyway.

### 6. A real Deluge over USB MIDI and sysex (v2)

**Design note for the protocol ticket.** The map wants "one protocol, so a real Deluge can be a second backend". The cleanest way to get that is a small C++ **Deluge bridge** backend that speaks the same protocol on one side and USB MIDI and sysex on the other, so the GUI never talks MIDI itself. Under that design the GUI toolkit's MIDI support matters little.

- **macOS.** CoreMIDI directly, or through a library:
  - RtMidi 6.1.0: MIT, released 2026-10-15, has an `ANDROID_AMIDI` API.
  - libremidi 5.4.3: BSD-2 plus MIT (RtMidi-derived), released 2026-01-18. It is C++20 and uses CoreMIDI on macOS 11 and later. Its changelog since v5.4 says "Port the Android backend from RtMidi", which isn't in a release yet ([libremidi README][libremidi]). Under MIDI 2, sysex handling is left to the library's user.
- **Android.** Apps "must still use the `MidiManager` to discover and open `MidiDevice` objects". Native code then takes over through `AMidiDevice_fromJava` and `AMidiOutputPort_receive` and `AMidiInputPort_send` (NDK r20b or later) ([AMidi guide][android-amidi]). So on Android the bridge needs a little Kotlin to open the device, whatever the toolkit.
- **Toolkit-level options, if the GUI ever talks MIDI itself:**
  - **Flutter:** `flutter_midi_command` 1.4.0 (BSD-3, 2026-10-09) wraps CoreMIDI and `android.media.midi` and has a typed `SysExMessage`. Its tracker has closed bugs about large and split sysex on macOS and Android ("Fixed size of MIDIPacketList prevents sending of bigger SysEx data", "MacOS app crashes when sending large SysEx messages"), so test large Deluge sysex early.
  - **JUCE:** MIDI is built in, with `juce_CoreMidi_mac.mm` and `juce_Midi_android.cpp` in `juce_audio_devices`.
  - **Qt and Slint:** use the C++ libraries above.

## Custom drawing for the v2 sound editor

Knobs, envelopes and dense parameter pages are custom widgets in every toolkit. Native controls don't help here.

- **Qt Quick** has `Shape` and `ShapePath`, `Canvas`, and `QQuickPaintedItem` for C++ painting. Custom controls should build on the Basic or Fusion style, because the macOS style "is not suitable for customizing" ([macOS style][qt-macos-style]). Expect the editor to look consistent across platforms rather than native.
- **Flutter**'s `CustomPainter` with Impeller is the most direct for this kind of work, and golden tests cover it well.
- **JUCE** is strongest here (rotary `Slider`, `Graphics`), which is why audio plugins use it. That doesn't outweigh criteria 1, 3 and 5.

## Facts the protocol and prototype tickets need

1. **Process model, macOS.** The GUI starts `deluge-engine` from inside the app bundle with `QProcess` (or Flutter's `Process.start`) and an absolute path. The GUI treats `CrashExit`, an unexpected exit, or a missed heartbeat as a freeze and restarts the Engine. A heartbeat event in the protocol catches hangs that don't exit: `FREEZE_WITH_ERROR` aborts (spec §3.4), but a busy loop wouldn't.
2. **Transport.** A duplex byte stream with length-prefixed frames. On macOS it can run over the child's stdin and stdout, which needs no socket path or cleanup, or over a Unix domain socket (`QLocalSocket`, or `dart:io` with `InternetAddressType.unix`). On Android the stdio option doesn't exist: the app process and the `:engine` service process need a Unix domain socket or Binder. Design the frames to be transport-agnostic, and use a Unix socket on both platforms if one code path is wanted.
3. **Encoding.** Spec §3.7 already asks for serialisable commands and events. With Qt, one C++ protocol library serves the GUI, the Engine and the Deluge bridge. If Flutter is chosen, use a schema with official C++ and Dart generators: protobuf, with Dart `protobuf` 6.1.0 and `protoc_plugin` 25.1.0 (2026-09-11).
4. **Android Engine.** The Engine is built as `libengine.so` in the APK and run by a `Service` declared with `android:process=":engine"`, which loads it through JNI. One Engine per process holds, because the firmware is all globals. After a freeze kills the `:engine` process, `ServiceConnection.onServiceDisconnected` fires ("typically ... when the process hosting the service has crashed or been killed"). The binding stays active, and `onServiceConnected` fires again "when the Service is next running", so the GUI reconnects its socket then ([ServiceConnection][android-serviceconn]). Spawning a separate executable isn't an option ([Android 10][android-10]).
5. **Sandbox and signing (macOS).** Decide whether the app is sandboxed. If it is, the Engine helper is signed with exactly `app-sandbox` and `inherit`, and it reads the card folder through the parent's user-selected access. If it isn't, use the hardened runtime and notarise without App Sandbox. This decision feeds the map's open question on packaging and signing.
6. **CI.** On `macos-latest` (macOS 26 arm64), install Qt with `jurplel/install-qt-action@v4` (aqtinstall) or `brew install qt`. Run QML tests with `QT_QPA_PLATFORM=offscreen`. The Flutter equivalent is `subosito/flutter-action@v2`, then `flutter test` and `flutter test integration_test -d macos`.
7. **MIDI and sysex (v2).** A C++ Deluge bridge using RtMidi 6.1.0 or libremidi on macOS. On Android, Kotlin `MidiManager.openDevice` followed by AMidi in native code.

## Risks

- **Qt Quick's macOS style is only nearly native.** Seven controls fall back to Fusion, including `Switch` and `TabBar`, so avoid them or accept a non-native look. The style also can change between minor versions ([macOS style][qt-macos-style]). The prototype ticket should check that the v1 screens look right.
- **Agents build Qt more slowly and know QML less well than Flutter.** The test harness is less turnkey: no update-goldens flow and no MCP driver. Budget a small helper for golden images built on `grabImage().save()` and `equals()`.
- **Installing Qt in CI goes through a third-party action**, because the official installer needs an account. LTS patch releases go commercial-only after a while, so the open-source path is to track the newest minor release.
- **Android Engine-as-service is untested for every toolkit.** Audio from a separate process (Oboe or AAudio in the service) and Android's background limits are beyond this research. That is the map's open question "Running the Engine as a separate process on Android".
- **If Flutter is chosen instead:**
  - The macOS look depends on `macos_ui`, which hasn't had a release in 13 months.
  - The protocol is implemented twice, in C++ and Dart, which code generation mitigates.
  - App Sandbox is on by default.
  - Golden tests are platform-sensitive.
- **Sysex size.** Large sysex has broken MIDI wrappers before (see the flutter_midi_command bugs). Whatever library the bridge uses, test it with the Deluge's largest messages.

## Others considered

- **SwiftUI or AppKit, with a separate Android UI.** This would feel the most native on macOS, but it fails criterion 2 without a second UI codebase. Skip (skip.dev) turns SwiftUI into Jetpack Compose but lists only iOS and Android, not macOS ([Skip docs][skip]).
- **Compose Multiplatform.** Stable on Android, iOS and desktop, but its desktop material shows Material components and no native macOS look ([Compose Multiplatform][compose-mp]).
- **Slint** came third. Its agent testing (headless backend plus MCP) is attractive, but the test API is internal and not semver, the macOS look is emulated, and Android is Rust-first.
- **JUCE** came last for the GUI: it isn't native-looking, has the weakest UI testing, and is AGPL. Its `ChildProcessCoordinator` heartbeat pattern is worth copying into the protocol.

## Sources

Versions and dates as of 2026-11-24.

- Qt 6.12.1 docs (Qt 6.12 LTS released 2026-09-30, 6.12.1 2026-11-24, [Qt releases][qt-releases]): [styles][qt-styles], [macOS style][qt-macos-style], [MenuBar][qt-menubar], [FolderDialog][qt-folderdialog], [Qt Quick Controls][qt-controls], [Qt Quick Test][qt-quicktest], [TestCase][qt-testcase], [QProcess][qt-qprocess], [QLocalSocket][qt-qlocalsocket], [Android getting started][qt-android], [Android services][qt-android-services], [Qt Remote Objects][qt-remoteobjects], [LGPL obligations][qt-lgpl], [open-source installer][qt-installer], [Homebrew qt 6.12.0][brew-qt]
- Flutter 3.50.1 (stable, 2026-11-20, Dart 3.14.0; from `releases_macos.json`): [building macOS apps][fl-macos-build], [Impeller][fl-impeller], [PlatformMenuBar][fl-menubar], [macOS platform views][fl-platform-views], [testing overview][fl-testing], [matchesGoldenFile][fl-golden], [integration tests][fl-integration], [platform channels][fl-channels], [LICENSE][fl-license], [Dart MCP server][dart-mcp], [Process.start][dart-process], [InternetAddress][dart-inetaddr]; pub.dev: [macos_ui 2.2.2][pub-macos-ui], [file_selector 1.1.0][pub-file-selector], [flutter_midi_command 1.4.0][pub-fmc]
- Slint 1.19.1 (2026-11-24): [styles][slint-styles], [Android][slint-android], [testing README][slint-testing], [CHANGELOG][slint-changelog], [LICENSE.md][slint-license]
- JUCE 9.0.6 (2026-11-19): [releases][juce-releases], [LICENSE.md][juce-license], [ChildProcessCoordinator][juce-coordinator], [juce_SharedCode_posix.h][juce-posix], [LookAndFeel_V4][juce-lnf]
- Android: [Android 10 behaviour changes][android-10], [service element][android-service], [ServiceConnection][android-serviceconn], [AMidi guide][android-amidi]
- MIDI libraries: [libremidi][libremidi] 5.4.3 (2026-01-18), [RtMidi][rtmidi] 6.1.0 (2026-10-15)
- Apple: [DTS forum answers on embedded helpers][apple-forum-helper]. The official doc "Embedding a command-line tool in a sandboxed app" would not render for fetching.
- CI: [GitHub runner images][gh-runner]
- Others: [Skip][skip], [Compose Multiplatform][compose-mp]

[qt-releases]: https://www.qt.io/blog/tag/releases
[qt-styles]: https://doc.qt.io/qt-6/qtquickcontrols-styles.html
[qt-macos-style]: https://doc.qt.io/qt-6/qtquickcontrols-macos.html
[qt-menubar]: https://doc.qt.io/qt-6/qml-qtquick-controls-menubar.html
[qt-folderdialog]: https://doc.qt.io/qt-6/qml-qtquick-dialogs-folderdialog.html
[qt-controls]: https://doc.qt.io/qt-6/qtquickcontrols-index.html
[qt-quicktest]: https://doc.qt.io/qt-6/qtquicktest-index.html
[qt-testcase]: https://doc.qt.io/qt-6/qml-qttest-testcase.html
[qt-qprocess]: https://doc.qt.io/qt-6/qprocess.html
[qt-qlocalsocket]: https://doc.qt.io/qt-6/qlocalsocket.html
[qt-android]: https://doc.qt.io/qt-6/android-getting-started.html
[qt-android-services]: https://doc.qt.io/qt-6/android-services.html
[qt-remoteobjects]: https://doc.qt.io/qt-6/qtremoteobjects-index.html
[qt-lgpl]: https://www.qt.io/licensing/open-source-lgpl-obligations
[qt-installer]: https://www.qt.io/download-qt-installer-oss
[brew-qt]: https://formulae.brew.sh/formula/qt
[fl-macos-build]: https://docs.flutter.dev/platform-integration/macos/building
[fl-impeller]: https://docs.flutter.dev/perf/impeller
[fl-menubar]: https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html
[fl-platform-views]: https://docs.flutter.dev/platform-integration/macos/platform-views
[fl-testing]: https://docs.flutter.dev/testing/overview
[fl-golden]: https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html
[fl-integration]: https://docs.flutter.dev/testing/integration-tests
[fl-channels]: https://docs.flutter.dev/platform-integration/platform-channels
[fl-license]: https://github.com/flutter/flutter/blob/master/LICENSE
[dart-mcp]: https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server
[dart-process]: https://api.flutter.dev/flutter/dart-io/Process/start.html
[dart-inetaddr]: https://api.dart.dev/dart-io/InternetAddress/InternetAddress.html
[pub-macos-ui]: https://pub.dev/packages/macos_ui
[pub-file-selector]: https://pub.dev/packages/file_selector
[pub-fmc]: https://pub.dev/packages/flutter_midi_command
[slint-styles]: https://docs.slint.dev/latest/docs/slint/reference/std-widgets/style/
[slint-android]: https://docs.slint.dev/latest/docs/rust/slint/android/
[slint-testing]: https://github.com/slint-ui/slint/blob/master/internal/backends/testing/README.md
[slint-changelog]: https://github.com/slint-ui/slint/blob/master/CHANGELOG.md
[slint-license]: https://github.com/slint-ui/slint/blob/master/LICENSE.md
[juce-releases]: https://github.com/juce-framework/JUCE/releases
[juce-license]: https://github.com/juce-framework/JUCE/blob/master/LICENSE.md
[juce-coordinator]: https://docs.juce.com/master/classjuce_1_1ChildProcessCoordinator.html
[juce-posix]: https://github.com/juce-framework/JUCE/blob/master/modules/juce_core/native/juce_SharedCode_posix.h
[juce-lnf]: https://docs.juce.com/master/classjuce_1_1LookAndFeel__V4.html
[android-10]: https://developer.android.com/about/versions/10/behavior-changes-10
[android-service]: https://developer.android.com/guide/topics/manifest/service-element
[android-serviceconn]: https://developer.android.com/reference/android/content/ServiceConnection
[android-amidi]: https://developer.android.com/ndk/guides/audio/midi
[libremidi]: https://github.com/celtera/libremidi
[rtmidi]: https://github.com/thestk/rtmidi
[apple-forum-helper]: https://developer.apple.com/forums/thread/680212
[gh-runner]: https://github.com/actions/runner-images
[skip]: https://skip.dev/docs/
[compose-mp]: https://kotlinlang.org/compose-multiplatform/
