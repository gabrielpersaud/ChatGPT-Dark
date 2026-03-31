//
//  ChatGPT_DarkApp.swift
//  ChatGPT Dark
//
//  Created by Gabe Persaud on 3/29/26.
//

import SwiftUI
import AppKit
import ServiceManagement
import Combine

private var lastApplyTime = Date.distantPast
private let chatGPTBundleIdentifier = "com.openai.chat"
private let sipSetupWindowController = SIPSetupWindowController()
private let fridaInstallController = FridaInstallController()
private let privateFridaRuntimeDirectoryName = "PrivatePython"
private let didResolveLoginItemPreferenceKey = "DidResolveLoginItemPreference"
let primaryButtonSwapAnimation = Animation.easeInOut(duration: 0.24)

enum SIPStatusCheck {
    case disabled
    case requiresSetup(String)
}

struct FridaInstallFailure: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

struct BundledFridaRuntime {
    let rootURL: URL

    var pythonHomeURL: URL {
        rootURL.appendingPathComponent("runtime", isDirectory: true)
    }

    var pythonExecutableURL: URL {
        pythonHomeURL.appendingPathComponent("bin/python3")
    }

    var sitePackagesURL: URL {
        rootURL.appendingPathComponent("site-packages", isDirectory: true)
    }

    var isAvailable: Bool {
        let fileManager = FileManager.default
        return fileManager.isExecutableFile(atPath: pythonExecutableURL.path)
            && fileManager.fileExists(atPath: sitePackagesURL.appendingPathComponent("frida").path)
            && fileManager.fileExists(atPath: sitePackagesURL.appendingPathComponent("frida_tools").path)
    }
}

@MainActor
final class FridaInstallController: ObservableObject {
    enum Phase: Equatable {
        case install
        case installing
        case installed
        case failed(String)
    }

    @Published private(set) var phase: Phase

    init() {
        phase = isFridaInstalled() ? .installed : .install
    }

    var primaryButtonTitle: String {
        switch phase {
        case .install, .failed:
            return "Install Frida"
        case .installing:
            return "Installing..."
        case .installed:
            return "Shut Down"
        }
    }

    var isInstalling: Bool {
        if case .installing = phase {
            return true
        }

        return false
    }

    func refresh() {
        guard !isInstalling else { return }
        phase = isFridaInstalled() ? .installed : .install
    }

    func beginInstall() {
        switch phase {
        case .install, .failed:
            break
        case .installing, .installed:
            return
        }

        withAnimation(primaryButtonSwapAnimation) {
            phase = .installing
        }

        Task {
            let result = await FridaInstallerBootstrap.install()

            switch result {
            case .success:
                withAnimation(primaryButtonSwapAnimation) {
                    phase = .installed
                }
            case .failure(let error):
                debugLog("Frida install failed: \(error.message)")
                withAnimation(primaryButtonSwapAnimation) {
                    phase = .failed(error.message)
                }
            }
        }
    }
}

enum FridaInstallerBootstrap {
    static func install() async -> Result<Void, FridaInstallFailure> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: runInstall())
            }
        }
    }

    private static func runInstall() -> Result<Void, FridaInstallFailure> {
        if bundledFridaRuntime() != nil {
            return .success(())
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", installScript]
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(FridaInstallFailure(message: error.localizedDescription))
        }

        if process.terminationStatus == 0, isFridaInstalled() {
            return .success(())
        }

        let stderrOutput = outputString(from: stderr)
        let stdoutOutput = outputString(from: stdout)
        let fallbackMessage = "Frida could not be installed automatically."
        let message = [stderrOutput, stdoutOutput, fallbackMessage]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? fallbackMessage

        return .failure(FridaInstallFailure(message: message))
    }

    private static func outputString(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static let installScript = #"""
PYTHON="/usr/bin/python3"
USER_BASE="$("$PYTHON" -m site --user-base 2>/dev/null)"
FRIDA="$USER_BASE/bin/frida"

HAS_PIP=1
"$PYTHON" -m pip --version >/dev/null 2>&1 || HAS_PIP=0

if [[ ! -x "$FRIDA" ]]; then
  if [[ $HAS_PIP -eq 0 ]]; then
    "$PYTHON" -m ensurepip --upgrade >/dev/null 2>&1 || true
  fi

  if ! "$PYTHON" -m pip --version >/dev/null 2>&1; then
    /bin/echo "pip could not be installed automatically."
    exit 1
  fi

  PIP_ERR="/tmp/chatgpt-dark-pip.$$.log"
  : > "$PIP_ERR"

  "$PYTHON" -m pip install --user frida-tools >/dev/null 2>"$PIP_ERR" || true

  if [[ ! -x "$FRIDA" ]]; then
    if /usr/bin/grep -Eqi 'outdated|upgrade pip|install --upgrade pip|requires pip|No matching distribution found|Could not find a version that satisfies the requirement|ERROR:' "$PIP_ERR"; then
      "$PYTHON" -m pip install --user --upgrade pip >/dev/null 2>&1 || true
      "$PYTHON" -m pip install --user frida-tools >/dev/null 2>>"$PIP_ERR" || true
    fi
  fi

  if [[ ! -x "$FRIDA" ]]; then
    /bin/cat "$PIP_ERR" 1>&2 || true
    /bin/rm -f "$PIP_ERR"
    exit 1
  fi

  /bin/rm -f "$PIP_ERR"
fi

exit 0
"""#
}

@main
struct ChatGPT_DarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

func startChatGPTMonitoring() {
    applyIfChatGPTAlreadyRunning()

    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didLaunchApplicationNotification,
        object: nil,
        queue: .main
    ) { notification in
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.bundleIdentifier == chatGPTBundleIdentifier
        else { return }

        applyDarkModeIfNeeded()
    }
}

func applyIfChatGPTAlreadyRunning() {
    let isRunning = NSWorkspace.shared.runningApplications.contains {
        $0.bundleIdentifier == chatGPTBundleIdentifier
    }

    if isRunning {
        applyDarkModeIfNeeded()
    }
}

func registerLoginItemIfNeeded() {
    guard #available(macOS 13.0, *) else { return }

    let service = SMAppService.mainApp
    let defaults = UserDefaults.standard
    let didResolvePreference = defaults.bool(forKey: didResolveLoginItemPreferenceKey)

    switch service.status {
    case .enabled:
        markLoginItemPreferenceResolved()
        return
    case .requiresApproval:
        debugLog("Login item registration requires approval in System Settings.")
    case .notRegistered, .notFound:
        guard !didResolvePreference else {
            debugLog("Login item was previously resolved; respecting current user setting.")
            return
        }

        if registerLoginItem(service) {
            markLoginItemPreferenceResolved()
        }
    @unknown default:
        guard !didResolvePreference else {
            debugLog("Skipping unknown login item state because user preference is already resolved.")
            return
        }

        if registerLoginItem(service) {
            markLoginItemPreferenceResolved()
        }
    }
}

func markLoginItemPreferenceResolved() {
    UserDefaults.standard.set(true, forKey: didResolveLoginItemPreferenceKey)
}

func bundledFridaRuntime() -> BundledFridaRuntime? {
    guard let resourceURL = Bundle.main.resourceURL else { return nil }

    let runtime = BundledFridaRuntime(
        rootURL: resourceURL.appendingPathComponent(privateFridaRuntimeDirectoryName, isDirectory: true)
    )

    return runtime.isAvailable ? runtime : nil
}

func legacyFridaExecutablePath() -> String {
    let process = Process()
    let output = Pipe()
    let error = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-m", "site", "--user-base"]
    process.standardOutput = output
    process.standardError = error

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return ""
    }

    guard process.terminationStatus == 0 else {
        return ""
    }

    let data = output.fileHandleForReading.readDataToEndOfFile()
    let userBase = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !userBase.isEmpty else {
        return ""
    }

    return "\(userBase)/bin/frida"
}

func isFridaInstalled() -> Bool {
    if bundledFridaRuntime() != nil {
        return true
    }

    let path = legacyFridaExecutablePath()
    guard !path.isEmpty else { return false }
    return FileManager.default.isExecutableFile(atPath: path)
}

func shellSingleQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
}

@available(macOS 13.0, *)
func registerLoginItem(_ service: SMAppService) -> Bool {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "<missing bundle identifier>"
    let bundlePath = Bundle.main.bundleURL.path

    do {
        try service.register()
        debugLog("Registered login item for \(bundleIdentifier) at \(bundlePath)")
        return true
    } catch {
        debugLog(
            "Failed to register login item for \(bundleIdentifier) at \(bundlePath): \(error.localizedDescription)"
        )
        return false
    }
}

func checkSIPStatus() -> SIPStatusCheck {
    let process = Process()
    let output = Pipe()
    let error = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
    process.arguments = ["status"]
    process.standardOutput = output
    process.standardError = error

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return .requiresSetup("Unable to determine System Integrity Protection status.")
    }

    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    let errorData = error.fileHandleForReading.readDataToEndOfFile()
    let combined = (String(data: outputData, encoding: .utf8) ?? "")
        + "\n"
        + (String(data: errorData, encoding: .utf8) ?? "")

    let statusLine = combined
        .split(whereSeparator: \.isNewline)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { !$0.isEmpty })
        ?? "System Integrity Protection appears to be enabled."

    if statusLine.lowercased().contains("disabled") {
        return .disabled
    }

    return .requiresSetup(statusLine)
}

func applyDarkModeIfNeeded() {
    let now = Date()
    guard now.timeIntervalSince(lastApplyTime) > 3 else { return }
    lastApplyTime = now
    applyDarkMode()
}

func applyDarkMode() {
    let bundledRuntime = bundledFridaRuntime()
    let bundledPythonPath = bundledRuntime?.pythonExecutableURL.path ?? ""
    let bundledPythonHome = bundledRuntime?.pythonHomeURL.path ?? ""
    let bundledSitePackages = bundledRuntime?.sitePackagesURL.path ?? ""

    let shellScript = #"""
APP_NAME="ChatGPT"
BUNDLED_PYTHON=\#(shellSingleQuoted(bundledPythonPath))
BUNDLED_PYTHONHOME=\#(shellSingleQuoted(bundledPythonHome))
BUNDLED_SITE_PACKAGES=\#(shellSingleQuoted(bundledSitePackages))
LEGACY_PYTHON="/usr/bin/python3"

show_dialog_and_quit() {
  /usr/bin/osascript -e "display dialog \"$1\" buttons {\"OK\"}"
  exit 0
}

log() {
  /bin/echo "[ChatGPT Dark] $*" 1>&2
}

typeset -a FRIDA_CMD

if [[ -n "$BUNDLED_PYTHON" && -x "$BUNDLED_PYTHON" && -d "$BUNDLED_SITE_PACKAGES/frida_tools" ]]; then
  export PYTHONHOME="$BUNDLED_PYTHONHOME"
  export PYTHONPATH="$BUNDLED_SITE_PACKAGES"
  FRIDA_CMD=("$BUNDLED_PYTHON" -m frida_tools.repl)
else
  USER_BASE="$("$LEGACY_PYTHON" -m site --user-base 2>/dev/null)"
  FRIDA="$USER_BASE/bin/frida"

  if [[ ! -x "$FRIDA" ]]; then
    show_dialog_and_quit "Frida runtime is missing from this copy of ChatGPT Dark.\n\nRebuild or reinstall the app."
  fi

  FRIDA_CMD=("$FRIDA")
fi

ALL_PIDS="$(/usr/bin/pgrep -x "$APP_NAME" | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/[[:space:]]*$//')"
PID="$(/bin/echo "$ALL_PIDS" | /usr/bin/awk '{print $1}')"

if [[ -z "$PID" ]]; then
  exit 0
fi

log
log "=== $(/bin/date '+%Y-%m-%d %H:%M:%S') ChatGPT Dark apply ==="
log "ALL_PIDS=$ALL_PIDS"
log "PID=$PID"
log "FRIDA_CMD=${FRIDA_CMD[*]}"
log "pgrep -fl output:"
/usr/bin/pgrep -fl "$APP_NAME" 1>&2 || true
log "selected pid details:"
/bin/ps -p "$PID" -o pid=,ppid=,uid=,comm=,args= 1>&2 || true

TMP_JS="/tmp/inject-dark-cgpt.$$.js"

cat > "$TMP_JS" <<'EOF'
'use strict';

send({
  type: 'script',
  process: {
    id: Process.id,
    arch: Process.arch,
    platform: Process.platform,
    mainModuleName: Process.mainModule ? Process.mainModule.name : null,
    mainModulePath: Process.mainModule ? Process.mainModule.path : null
  }
});

if (typeof ObjC === 'undefined' || !ObjC.available) {
  send({ type: 'script', event: 'objc-unavailable' });
} else {
  ObjC.schedule(ObjC.mainQueue, function () {
    const NSAppearance = ObjC.classes.NSAppearance;
    const dark = NSAppearance.appearanceNamed_("NSAppearanceNameDarkAqua");

    const NSApplication = ObjC.classes.NSApplication;
    const NSView = ObjC.classes.NSView;

    const appSel = NSApplication["- effectiveAppearance"];
    const viewSel = NSView["- effectiveAppearance"];

    Interceptor.attach(appSel.implementation, {
      onLeave(retval) {
        retval.replace(dark.handle);
      }
    });

    Interceptor.attach(viewSel.implementation, {
      onLeave(retval) {
        retval.replace(dark.handle);
      }
    });

    send({
      type: 'script',
      event: 'objc-available',
      processName: ObjC.classes.NSProcessInfo.processInfo().processName().toString()
    });

    try {
      const app = NSApplication.sharedApplication();
      app.setAppearance_(dark);

      const windows = app.windows();
      const count = windows.count();
      send({ type: 'script', event: 'window-count', count: count });

      for (let i = 0; i < count; i++) {
        const w = windows.objectAtIndex_(i);
        w.setAppearance_(dark);
        const cv = w.contentView();
        if (cv) cv.setAppearance_(dark);
      }
    } catch (e) {
      send({ type: 'script', event: 'objc-exception', error: String(e) });
    }
  });
}
EOF

STATUS=0
{ /bin/sleep 1; /bin/echo exit; } | "${FRIDA_CMD[@]}" -q -p "$PID" -l "$TMP_JS" 2>&1 || STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  log "injection completed successfully"
else
  log "injection failed with status $STATUS"
fi

/bin/rm -f "$TMP_JS"

if [[ $STATUS -ne 0 ]]; then
  show_dialog_and_quit "Failed to apply dark mode to ChatGPT."
fi

exit 0
"""#

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", shellScript]

    do {
        try process.run()
    } catch {
        print("Failed to run ChatGPT Dark helper: \(error)")
    }
}

func debugLog(_ message: String) {
#if DEBUG
    print("ChatGPT Dark: \(message)")
#endif
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundlePath = Bundle.main.bundleURL.path
        if bundlePath.contains("/AppTranslocation/") {
            debugLog("Running from AppTranslocation: \(bundlePath)")
        }

        registerLoginItemIfNeeded()

        switch checkSIPStatus() {
        case .disabled:
            startChatGPTMonitoring()
        case .requiresSetup(let statusLine):
            debugLog("SIP setup required: \(statusLine)")
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.async {
                sipSetupWindowController.show(statusLine: statusLine)
            }
        }
    }
}

final class SIPSetupWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers == [.command], event.charactersIgnoringModifiers?.lowercased() == "w" {
            close()
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    func applyChromeStyling() {
        guard let contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.masksToBounds = true

        let maskLayer = CAShapeLayer()
        maskLayer.frame = contentView.bounds
        maskLayer.path = dialogChromeMaskPath(in: contentView.bounds)
        contentView.layer?.mask = maskLayer
    }
}

final class SIPSetupWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(statusLine: String) {
        NSApp.setActivationPolicy(.regular)
        fridaInstallController.refresh()

        if window == nil {
            let window = SIPSetupWindow(
                contentRect: NSRect(x: 0, y: 0, width: 750, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            window.isMovableByWindowBackground = true
            window.hasShadow = true
            window.isOpaque = false
            window.center()
            window.setFrameAutosaveName("SIPSetupWindow")
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace]
            window.delegate = self
            self.window = window
        }

        let hostingView = NSHostingView(
            rootView: ContentView(
                statusLine: statusLine,
                fridaInstallController: fridaInstallController
            )
        )

        window?.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        let fittingSize = hostingView.fittingSize
        if let window {
            let currentFrame = window.frame
            let centeredOrigin = NSPoint(
                x: currentFrame.midX - (fittingSize.width / 2),
                y: currentFrame.midY - (fittingSize.height / 2)
            )
            let targetFrame = NSRect(origin: centeredOrigin, size: fittingSize)
            window.setFrame(targetFrame, display: false)
        }

        (window as? SIPSetupWindow)?.applyChromeStyling()

        NSApp.activate(ignoringOtherApps: true)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowDidResize(_ notification: Notification) {
        (notification.object as? SIPSetupWindow)?.applyChromeStyling()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

private func dialogChromeMaskPath(in rect: CGRect) -> CGPath {
    let topRadius = min(dialogTopChromeCornerRadius, min(rect.width, rect.height) / 2)
    let bottomRadius = min(dialogChromeCornerRadius, min(rect.width, rect.height) / 2)

    let minX = rect.minX
    let maxX = rect.maxX
    let minY = rect.minY
    let maxY = rect.maxY

    let path = CGMutablePath()
    path.move(to: CGPoint(x: minX + topRadius, y: minY))
    path.addLine(to: CGPoint(x: maxX - topRadius, y: minY))
    path.addQuadCurve(
        to: CGPoint(x: maxX, y: minY + topRadius),
        control: CGPoint(x: maxX, y: minY)
    )
    path.addLine(to: CGPoint(x: maxX, y: maxY - bottomRadius))
    path.addQuadCurve(
        to: CGPoint(x: maxX - bottomRadius, y: maxY),
        control: CGPoint(x: maxX, y: maxY)
    )
    path.addLine(to: CGPoint(x: minX + bottomRadius, y: maxY))
    path.addQuadCurve(
        to: CGPoint(x: minX, y: maxY - bottomRadius),
        control: CGPoint(x: minX, y: maxY)
    )
    path.addLine(to: CGPoint(x: minX, y: minY + topRadius))
    path.addQuadCurve(
        to: CGPoint(x: minX + topRadius, y: minY),
        control: CGPoint(x: minX, y: minY)
    )
    path.closeSubpath()
    return path
}
