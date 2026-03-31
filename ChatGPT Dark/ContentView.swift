//
//  ContentView.swift
//  ChatGPT Dark
//
//  Created by Gabe Persaud on 3/29/26.
//

import SwiftUI
import AppKit

let dialogChromeCornerRadius: CGFloat = 26
let dialogTopChromeCornerRadius: CGFloat = 14

private let sipInfoURL = URL(string: "https://support.apple.com/en-kg/guide/security/secb7ea06b49/web")!
private let disableSIPCommand = "csrutil disable"
private let dialogContentWidth: CGFloat = 700
private let dialogButtonRowWidth: CGFloat = dialogContentWidth * 0.75
private let developerToolsPromptAssetName = "DeveloperToolsAccess"
private let developerToolsPromptWidth: CGFloat = 260
private let developerToolsPromptAspectRatio: CGFloat = 600.0 / 486.0

struct ContentView: View {
    let statusLine: String
    @ObservedObject var fridaInstallController: FridaInstallController

    var body: some View {
        ZStack {
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.03, green: 0.04, blue: 0.06), location: 0.00),
                        .init(color: Color(red: 0.04, green: 0.07, blue: 0.10), location: 0.18),
                        .init(color: Color(red: 0.06, green: 0.11, blue: 0.15), location: 0.42),
                        .init(color: Color(red: 0.05, green: 0.08, blue: 0.11), location: 0.60),
                        .init(color: Color(red: 0.03, green: 0.04, blue: 0.05), location: 0.84),
                        .init(color: Color(red: 0.02, green: 0.03, blue: 0.04), location: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Ellipse()
                    .fill(Color(red: 0.22, green: 0.15, blue: 0.14).opacity(0.18))
                    .frame(width: 410, height: 190)
                    .rotationEffect(.degrees(-18))
                    .blur(radius: 58)
                    .offset(x: 54, y: 8)
                    .blendMode(.softLight)

                GradientNoiseOverlay()
                    .blendMode(.softLight)
                    .opacity(0.06)
            }
            .ignoresSafeArea()

            VStack {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    mainContentRow
                    footerButtons
                }
                .frame(maxWidth: dialogContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, 12)
        }
        .frame(width: 750)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.disabled)
        .focusEffectDisabled()
    }

    private var mainContentRow: some View {
        HStack(alignment: .top, spacing: 22) {
            stepsCard
                .frame(width: 382, alignment: .leading)

            DeveloperToolsAccessColumn()
                .frame(width: 296, alignment: .leading)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.09, green: 0.15, blue: 0.20))

                    Image(systemName: "shield.lefthalf.filled.slash")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.57, green: 0.89, blue: 0.93))
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 8) {
                    Text("System Integrity Protection must be disabled")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(.init("This tool uses Frida to inject into ChatGPT, which requires disabling SIP. To do this you must boot into Recovery Mode, open Terminal, and run the command below. [Apple SIP Guide](\(sipInfoURL.absoluteString))"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            warningStrip("Disabling SIP reduces MacOS security protections. To re-enable, do 'csrutil enable'.")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .padding(.leading, 30)
        .padding(.trailing, 18)
        .background(cardBackground(stronger: true))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Steps")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            CompactStep(
                index: "1",
                title: "Enter Recovery",
                detail: "Shut down -> hold power button for Startup Options. Options -> Continue -> Pick a volume/account and enter the password."
            )

            CompactStep(
                index: "2",
                title: "Open Terminal",
                detail: "Top menu bar -> Utilities -> Terminal."
            )

            CommandStep(
                index: "3",
                title: "Run the command",
                detail: "Type 'csrutil disable', hit return\nType 'y', hit return\nEnter MacOS username/password, then restart."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .padding(.leading, 30)
        .padding(.trailing, 18)
        .background(cardBackground())
    }

    private func warningStrip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.85, blue: 0.56))

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.98, green: 0.87, blue: 0.66))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.24, green: 0.18, blue: 0.07))
        )
    }

    private func cardBackground(stronger: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(stronger ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(stronger ? 0.10 : 0.07), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 16)
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Dismiss") {
                if let window = NSApp.keyWindow {
                    window.close()
                } else {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(DialogButtonStyle(prominent: false))
            .keyboardShortcut(.cancelAction)
            .keyboardShortcut("w", modifiers: .command)
            .focusable(false)
            .disabled(fridaInstallController.isInstalling)

            Button(action: handlePrimaryAction) {
                AnimatedButtonLabel(text: fridaInstallController.primaryButtonTitle)
            }
            .buttonStyle(PrimaryActionButtonStyle(phase: primaryButtonPhase))
            .keyboardShortcut(.defaultAction)
            .focusable(false)
        }
        .frame(maxWidth: dialogButtonRowWidth)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 13)
        .padding(.bottom, 3)
        .background(WindowDragShield())
    }

    private var primaryButtonPhase: PrimaryActionButtonStyle.Phase {
        switch fridaInstallController.phase {
        case .install, .failed:
            return .install
        case .installing:
            return .installing
        case .installed:
            return .shutdown
        }
    }

    private func handlePrimaryAction() {
        switch fridaInstallController.phase {
        case .install, .failed:
            fridaInstallController.beginInstall()
        case .installing:
            break
        case .installed:
            requestShutdown()
        }
    }

    private func requestShutdown() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"System Events\" to shut down"]

        do {
            try process.run()
        } catch {
            NSSound.beep()
        }
    }
}

private struct CompactStep: View {
    let index: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            stepBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stepBadge: some View {
        Text(index)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.05, green: 0.07, blue: 0.10))
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color(red: 0.57, green: 0.89, blue: 0.93))
            )
    }
}

private struct CommandStep: View {
    let index: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(index)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.07, blue: 0.10))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(red: 0.57, green: 0.89, blue: 0.93))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(disableSIPCommand)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.70, green: 0.93, blue: 0.97))
                .frame(width: 236)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.04, green: 0.06, blue: 0.09))
                )
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onTapGesture(perform: copyCommandToClipboard)

            photoBadge("Take a photo or write this down.\nThe clipboard will not carry over into recovery mode.")
                .frame(width: 264, alignment: .leading)
        }
    }

    private func copyCommandToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(disableSIPCommand, forType: .string)
    }

    private func photoBadge(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "camera")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.85, blue: 0.56))

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.98, green: 0.85, blue: 0.56))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.24, green: 0.18, blue: 0.07))
        )
    }
}

private struct DeveloperToolsAccessColumn: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(developerToolsPromptAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: developerToolsPromptWidth,
                    height: developerToolsPromptWidth * developerToolsPromptAspectRatio
                )

            Text("ChatGPT Dark will prompt you\nfor your password once per login session")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .frame(width: developerToolsPromptWidth, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 14)
    }
}

private struct GradientNoiseOverlay: View {
    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let step: CGFloat = 4

            for y in stride(from: CGFloat.zero, through: size.height, by: step) {
                for x in stride(from: CGFloat.zero, through: size.width, by: step) {
                    let value = noiseValue(x: x, y: y)
                    let alpha = 0.004 + abs(value - 0.5) * 0.012

                    let color: Color
                    if value < 0.33 {
                        color = Color.black.opacity(alpha * 0.90)
                    } else if value > 0.72 {
                        color = Color.white.opacity(alpha * 0.55)
                    } else {
                        color = Color(red: 0.42, green: 0.52, blue: 0.60).opacity(alpha * 0.28)
                    }

                    context.fill(
                        Path(CGRect(x: x, y: y, width: step, height: step)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func noiseValue(x: CGFloat, y: CGFloat) -> Double {
        let hashed = sin((x * 12.9898) + (y * 78.233)) * 43758.5453
        return hashed - floor(hashed)
    }
}

private struct DialogButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color(red: 0.05, green: 0.07, blue: 0.10) : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous)
                    .fill(
                        prominent
                        ? Color(red: 0.57, green: 0.89, blue: 0.93).opacity(configuration.isPressed ? 0.88 : 1.0)
                        : Color.white.opacity(configuration.isPressed ? 0.10 : 0.07)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(prominent ? 0.0 : 0.06), lineWidth: 1)
            )
    }
}

private struct AnimatedButtonLabel: View {
    let text: String

    var body: some View {
        ZStack {
            ForEach([text], id: \.self) { value in
                Text(value)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92)),
                            removal: .opacity.combined(with: .scale(scale: 0.84))
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .animation(primaryButtonSwapAnimation, value: text)
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    enum Phase {
        case install
        case installing
        case shutdown
    }

    let phase: Phase

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundView(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch phase {
        case .shutdown:
            return Color(red: 0.05, green: 0.07, blue: 0.10)
        case .install, .installing:
            return .white
        }
    }

    private var borderColor: Color {
        switch phase {
        case .shutdown:
            return Color.clear
        case .install:
            return Color.white.opacity(0.08)
        case .installing:
            return Color.white.opacity(0.12)
        }
    }

    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        switch phase {
        case .shutdown:
            RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous)
                .fill(Color(red: 0.57, green: 0.89, blue: 0.93).opacity(isPressed ? 0.88 : 1.0))
        case .install:
            RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous)
                .fill(Color(red: 0.16, green: 0.28, blue: 0.34).opacity(isPressed ? 0.88 : 1.0))
        case .installing:
            InstallingStripeBackground(isPressed: isPressed)
        }
    }
}

private struct InstallingStripeBackground: View {
    let isPressed: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let offset = CGFloat((seconds * 27).truncatingRemainder(dividingBy: 54))

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let clipPath = RoundedRectangle(cornerRadius: dialogChromeCornerRadius, style: .continuous)
                    .path(in: rect)

                context.clip(to: clipPath)
                context.fill(Path(rect), with: .color(Color(red: 0.17, green: 0.33, blue: 0.38).opacity(isPressed ? 0.90 : 1.0)))

                for stripeX in stride(from: -size.height - 140 + offset, through: size.width + 140, by: 54) {
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: stripeX, y: size.height))
                    stripe.addLine(to: CGPoint(x: stripeX + size.height, y: 0))

                    context.stroke(
                        stripe,
                        with: .color(Color.white.opacity(0.12)),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                }
            }
        }
    }
}

private struct WindowDragShield: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NonDraggableRegionView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class NonDraggableRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}
