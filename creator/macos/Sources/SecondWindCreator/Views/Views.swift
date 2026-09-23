// Every screen of the wizard. Kept deliberately plain: one column, big
// friendly text, one primary action per screen. macOS 11-safe SwiftUI only.
#if os(macOS)
import SwiftUI
import CreatorCore
import AppKit

struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.stage {
            case .welcome: WelcomeView()
            case .whichMac: WhichMacView()
            case .locks: LocksView()
            case .download: DownloadView()
            case .pickDisk: PickDiskView()
            case .confirm: ConfirmView()
            case .writing: WritingView()
            case .done: DoneView()
            }
        }
        .padding(32)
    }
}

struct StepHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(.title).fontWeight(.bold)
            Spacer()
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("⌘").font(.system(size: 44, weight: .bold))
                Text(L10n.welcomeTitle).font(.title).fontWeight(.bold)
            }
            Text(L10n.welcomeBody)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.welcomeNeeds)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                Spacer()
                Button(L10n.start) { state.stage = .whichMac }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct WhichMacView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepHeader(title: L10n.whichTitle)
            if let m = state.targetModel {
                CompatibilityCard(model: m)
            } else if !state.thisMac.isEmpty && !state.otherMac {
                Text(L10n.thisMacIs(state.thisMac[0].name, state.thisMac[0].aNumbers.joined(separator: ", ")))
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.installHere).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(L10n.yesThisMac) { state.chooseTarget(state.thisMac[0]) }
                        .keyboardShortcut(.defaultAction)
                    Button(L10n.otherMacBtn) { state.otherMac = true }
                }
            } else {
                Text(L10n.askANumber).fixedSize(horizontal: false, vertical: true)
                TextField("A1466", text: $state.aNumberInput)
                    .frame(maxWidth: 160)
                Text(L10n.whereANumber)
                    .font(.footnote).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if MacCatalog.normalizeANumber(state.aNumberInput) != nil {
                    if state.aNumberMatches.isEmpty {
                        Text(L10n.aNumberUnknown).foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.pickYear).font(.callout)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(state.aNumberMatches) { m in
                                    Button(m.name) { state.chooseTarget(m) }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
            }
            Spacer()
            HStack {
                Button(L10n.backBtn) {
                    if state.targetModel != nil { state.chooseTarget(nil) }
                    else if state.otherMac { state.otherMac = false }
                    else { state.stage = .welcome }
                }
                Spacer()
                Button(L10n.continueBtn) { state.stage = .locks }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!state.canContinueFromWhichMac)
            }
        }
    }
}

struct CompatibilityCard: View {
    @EnvironmentObject var state: AppState
    let model: MacModel

    var color: Color {
        switch model.support {
        case .verified, .expected: return .green
        case .partial: return .yellow
        case .beta: return .orange
        case .unsupported: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.name).font(.headline)
            Text(L10n.modelLine(model.aNumbers.joined(separator: ", "), model.year))
                .font(.callout).foregroundColor(.secondary)
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(L10n.supportLabel(model.support)).fontWeight(.semibold)
            }
            Text(L10n.isSpanish ? model.noteES : model.noteEN)
                .fixedSize(horizontal: false, vertical: true)
            if model.support.needsAcknowledgement {
                Toggle(isOn: $state.betaAccepted) {
                    Text(L10n.betaAck).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !model.support.allowsInstall {
                Text(L10n.dontWrite).foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

struct LocksView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: L10n.locksTitle)
            Toggle(isOn: $state.lockBackup) {
                Text(L10n.lock1).fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $state.lockErase) {
                Text(L10n.lock2).fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.lockPower)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !(state.lockBackup && state.lockErase) {
                Text(L10n.locksHint).font(.footnote).foregroundColor(.secondary)
            }
            Spacer()
            HStack {
                Button(L10n.backBtn) { state.stage = .whichMac }
                Spacer()
                Button(L10n.continueBtn) {
                    state.stage = .download
                    state.startDownloads()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!(state.lockBackup && state.lockErase))
            }
        }
    }
}

struct DownloadView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: L10n.downloadTitle)
            Text(L10n.downloadBody)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(L10n.downloadPayload)
                Spacer()
                if state.payloadDone {
                    Text(L10n.verified).foregroundColor(.green)
                } else {
                    ProgressView().scaleEffect(0.5)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.downloadISO)
                    Spacer()
                    if state.isoDone {
                        Text(L10n.verified).foregroundColor(.green)
                    } else {
                        Text("\(Int(state.isoProgress * 100)) %").foregroundColor(.secondary)
                    }
                }
                ProgressView(value: state.isoProgress)
            }

            if let error = state.downloadError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.retry) { state.startDownloads() }
            }
            Spacer()
            HStack {
                Button(L10n.backBtn) { state.stage = .locks }
                Spacer()
            }
        }
    }
}

struct PickDiskView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: L10n.pickTitle)
            Text(L10n.pickBody)
                .fixedSize(horizontal: false, vertical: true)

            if state.disks.isEmpty {
                VStack(spacing: 12) {
                    Text("🔌").font(.system(size: 40))
                    Text(L10n.pickEmpty)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.disks) { disk in
                        if state.fits(disk) {
                            Button(action: { state.selected = disk }) {
                                HStack {
                                    Text("💾")
                                    VStack(alignment: .leading) {
                                        Text(disk.name).fontWeight(.semibold)
                                        Text(disk.sizeLabel).font(.callout).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if state.selected == disk {
                                        Text("✓").fontWeight(.bold).foregroundColor(.accentColor)
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(state.selected == disk ? Color.accentColor : Color.gray.opacity(0.4))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // Too small for the payload: visible but not
                            // selectable, with the reason. A silently missing
                            // stick reads as "broken app" (learned live from
                            // an 8 GB stick that reported 7.7 real GB).
                            HStack {
                                Text("💾").opacity(0.4)
                                VStack(alignment: .leading) {
                                    Text(disk.name).fontWeight(.semibold).foregroundColor(.secondary)
                                    Text("\(disk.sizeLabel) — \(L10n.pickTooSmall(state.requiredLabel))")
                                        .font(.callout).foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.25))
                            )
                        }
                    }
                }
            }

            Button(L10n.refresh) { state.refreshDisks() }
            Spacer()
            HStack {
                Button(L10n.backBtn) { state.stage = .download }
                Spacer()
                Button(L10n.continueBtn) { state.stage = .confirm }
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.selected == nil)
            }
        }
        .onAppear { state.refreshDisks() }
    }
}

struct ConfirmView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: L10n.confirmTitle)
            if let disk = state.selected {
                Text(L10n.confirmBody(disk.name, disk.sizeLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.confirmType(L10n.confirmWord)).fontWeight(.semibold)
            TextField(L10n.confirmWord, text: $state.confirmText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: 220)
            Text(L10n.passwordNote)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = state.writeError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack {
                Button(L10n.backBtn) { state.stage = .pickDisk }
                Spacer()
                Button(L10n.confirmGo) { state.startWrite() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.confirmText.uppercased()
                        .trimmingCharacters(in: .whitespaces) != L10n.confirmWord)
            }
        }
    }
}

struct WritingView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: L10n.writingTitle)
            Text(L10n.writingBody)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(state.phaseLabel).font(.callout)
                    Spacer()
                    Text("\(Int(state.writeProgress * 100)) %").foregroundColor(.secondary)
                }
                ProgressView(value: state.writeProgress)
            }
            Spacer()
        }
    }
}

struct DoneView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(title: L10n.doneTitle)
            Text(L10n.doneSteps)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.rescueTitle).fontWeight(.bold)
                Text(L10n.rescueBody)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://\(L10n.rescueLink)")!)
                }) {
                    Text(L10n.rescueLink).underline()
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.accentColor)
            }
            Spacer()
            HStack {
                Button(L10n.makeAnother) { state.resetForAnother() }
                Spacer()
                Button(L10n.quit) { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
#endif
