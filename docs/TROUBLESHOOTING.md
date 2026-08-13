# Troubleshooting (host environment)

Problems with the machine you run `flutter run` on. For container issues see
`docs/DOCKER.md`.

## Gradle fails with `* What went wrong: 26.0.1`

```
FAILURE: Build failed with an exception.
* What went wrong:
26.0.1
BUILD FAILED in 965ms
```

**Cause.** Gradle 8.14 cannot run on JDK 26. The bare version number *is* the error
message — Gradle chokes before it can produce a readable one. A very short build
time (under ~2s) is the tell.

This bites even when `flutter config --jdk-dir` is already set to a good JDK,
because that setting only covers builds the **Flutter CLI** launches. Anything else
that starts a Gradle daemon — VS Code's Java extension, Android Studio, a direct
`gradlew` call — can start one under `JAVA_HOME`, and Gradle will happily **reuse
that daemon** for your next `flutter run`. So the same command fails or succeeds
depending on which daemon happens to be alive. 

**Fix.** Pin the JVM Gradle itself runs on, at the machine level. Create
`~/.gradle/gradle.properties` (i.e. `C:\Users\<you>\.gradle\gradle.properties`):

```
org.gradle.java.home=C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot
```

Use **forward slashes** — backslashes are escape characters in a properties file.
Point it at whatever JDK 17 or 21 you have; adjust the path to match your machine.

Then kill any daemon already running on the wrong JDK, or it will be reused:

```bash
taskkill /F /IM java.exe
```

Verify — a healthy build takes tens of seconds, not milliseconds:

```bash
flutter build apk --debug
```

**Why not just change `JAVA_HOME`?** You can, but it affects every Java tool on the
machine. `~/.gradle/gradle.properties` scopes the change to Gradle only, and is not
committed, so it does not force a path on teammates or CI.

**Why JDK 17 and not 26?** The project needs *two* incompatible JVMs: Gradle 8.14
rejects JDK 26, and `firebase-tools` requires JDK 21+. No single host JDK satisfies
both — which is exactly why the Firebase emulators run in Docker with their own
Java 21. Keep JDK 17 for Gradle on the host and let the container handle the rest.

## Emulator connections time out with no error

The Firebase emulators speak plain HTTP, and Android blocks cleartext by default
from API 28. `android/app/src/debug/AndroidManifest.xml` sets
`android:usesCleartextTraffic="true"` for the debug build type only. If you see
silent timeouts against the emulators, check that file first.

Also check the host: an Android emulator reaches your machine at `10.0.2.2`, not
`localhost`. A physical device needs your PC's LAN IP. See `docs/DOCKER.md`.

## Running on a physical Android phone

Better than the emulator for this app — real GPS for the map work, real
performance, and no virtualization overhead on a laptop that struggles with it.

**On the phone:** Settings → About phone → tap **Build number** seven times to
unlock Developer options, then Developer options → enable **USB debugging**.
Plug in over USB and accept the "Allow USB debugging?" prompt (tick *Always
allow*). Confirm the laptop sees it:

```bash
flutter devices
```

**The catch: `10.0.2.2` does not work on a physical device.** That address is the
Android *emulator's* alias for the host loopback. A real phone is a separate
machine on your Wi-Fi and needs your PC's LAN IP.

That is what `config/local.json` is for — a gitignored, per-developer copy of
`config/dev.json` carrying your own IP. Rather than reading `ipconfig` and
picking the right adapter by eye, ask:

```bash
node scripts/emulator-host.mjs
```

It lists every interface, marks the virtual ones a phone cannot reach (WSL,
VirtualBox, Hyper-V), checks which address the emulator actually answers on, and
prints the run command with the right value. Add `--write` to put it straight
into `config/local.json`.

Then:

```bash
flutter run --dart-define-from-file=config/local.json
```

Check the boot log line — it prints the resolved config:

```
Lakbayan config — emulators: true, host: 192.168.x.x, ...
```

### "Everything is empty" is usually this

**Your IP changes.** It comes from DHCP, so it moves when the lease renews, the
router restarts, or you rejoin the network — and `config/local.json` still holds
the old one. The app then points at an address nothing is listening on.

That failure is silent by design of the SDK: `useFirestoreEmulator` only records
an endpoint, it performs no I/O and cannot fail. Combined with offline
persistence, every read serves an empty cache, so Explore renders an empty list
and looks exactly like a database with no content in it.

Two things now catch this:

- The app **probes the emulator on startup** and, in debug builds, shows a red
  strip along the bottom reading *"No emulator at 192.168.x.x — lists will look
  empty"*. A green strip naming the host means the connection is fine and the
  data really is missing.
- `node scripts/emulator-host.mjs` tells you the address that works right now.

Re-run the app after changing it. Dart-defines are compiled in, so a hot reload
will not pick it up.

**The phone and the laptop must be on the same Wi-Fi network.** Many campus and
public networks enable client isolation, which blocks device-to-device traffic
entirely; a phone hotspot that the laptop joins is the usual workaround.

### Windows Firewall will block this

This is the most common failure, and it looks like a hang rather than an error:
the app boots but every Firebase call times out. Windows blocks inbound
connections to the emulator ports from other machines by default.

Open an **Administrator** PowerShell and allow them:

```powershell
New-NetFirewallRule -DisplayName "Firebase Emulators (LAN)" -Direction Inbound -Protocol TCP -LocalPort 4000,5001,8080,9099,9199 -Action Allow -Profile Private
```

`-Profile Private` limits this to networks you have marked as private. If your
Wi-Fi is set to Public, either change it to Private or the rule will not apply.

To verify from the phone before debugging further, open
`http://<your-ip>:4000` in the phone's browser — the Emulator Suite UI should
load. If it does not, the problem is the network or firewall, not the app.

### Wireless debugging (Android 11+)

Same USB steps, then Developer options → **Wireless debugging** → *Pair device
with pairing code*, and on the laptop:

```bash
adb pair <phone-ip>:<pairing-port>
```

```bash
adb connect <phone-ip>:<debug-port>
```

## `flutter run` picks the wrong device

```bash
flutter devices
```

```bash
flutter run -d emulator-5554
```

Note that `flutter run` must be run on the **host**, never in the toolchain
container — a container cannot reach the Android emulator or a USB device.
