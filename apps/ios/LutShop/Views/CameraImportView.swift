import SwiftUI

struct CameraImportView: View {
    @EnvironmentObject private var state: LutShopAppState
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusPanel
                    hotspotPanel
                    sonySetupPanel
                    ftpPanel
                    receivePanel
                    recentPanel
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "Camera Connection"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(Text(String(localized: "Camera import settings")))
                }
            }
            .sheet(isPresented: $showSettings) {
                CameraImportSettingsSheet()
                    .environmentObject(state)
                    .presentationDetents([.medium, .large])
            }
            .onDisappear {
                state.stopCameraDiscovery()
            }
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Sony Auto Import"))
                        .font(.system(size: 26, weight: .bold))
                    Text(state.cameraSession?.name ?? String(localized: "No active camera session"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
                statusBadge
            }

            HStack(spacing: 10) {
                metric(value: "\(state.cameraSession?.receivedCount ?? 0)", label: String(localized: "received"))
                metric(value: state.cameraSettings.format.title, label: String(localized: "format"))
                metric(value: "\(state.ftpReceiverConfiguration.port)", label: String(localized: "port"))
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.06)))
    }

    private var statusBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
            Text((state.cameraSession?.status ?? .idle).title)
                .font(.system(size: 13, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.3), in: Capsule())
    }

    private var statusColor: Color {
        switch state.cameraSession?.status ?? .idle {
        case .idle, .stopped:
            return .white.opacity(0.48)
        case .waiting:
            return .yellow
        case .receiving:
            return Color.accentGreen
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }

    private var hotspotPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Personal Hotspot"))
                .font(.system(size: 15, weight: .bold))
            Text(String(localized: "Turn on iPhone Personal Hotspot, then connect your Sony camera to that hotspot once. The camera can remember the hotspot password for later shoots."))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            settingRow(title: String(localized: "Current Server"), value: state.ftpReceiverAddressDisplay)
            settingRow(title: String(localized: "FTP Endpoint"), value: state.ftpReceiverSummary)
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.05)))
    }

    private var sonySetupPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Sony A74 Setup"))
                .font(.system(size: 15, weight: .bold))

            instructionRow(index: "1", text: String(localized: "On the camera, connect Wi-Fi to your iPhone Personal Hotspot."))
            instructionRow(index: "2", text: String(localized: "Open FTP Transfer settings and edit Server 1."))
            instructionRow(index: "3", text: String(localized: "Use the server address, port, user, and password shown below."))
            instructionRow(index: "4", text: String(localized: "After first setup, you usually only need to update Host if the phone address changes."))
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.05)))
    }

    private var ftpPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "FTP Receiver"))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(String(localized: "Sony Server 1"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
            }
            settingRow(title: String(localized: "Server"), value: state.ftpReceiverAddressDisplay)
            settingRow(title: String(localized: "Port"), value: "\(state.ftpReceiverConfiguration.port)")
            settingRow(title: String(localized: "User"), value: state.ftpReceiverConfiguration.username)
            settingRow(title: String(localized: "Password"), value: state.ftpReceiverConfiguration.password)
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.05)))
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .textSelection(.enabled)
        }
    }

    private func instructionRow(index: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(Color.accentGreen, in: Circle())
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var receivePanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    state.startCameraReceive()
                } label: {
                    Label(String(localized: "Start Receive"), systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentGreen)

                Button {
                    state.stopCameraReceive()
                } label: {
                    Label(String(localized: "Stop"), systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var recentPanel: some View {
        if let session = state.cameraSession {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Current Session"))
                    .font(.system(size: 15, weight: .bold))
                settingRow(title: String(localized: "Name"), value: session.name)
                settingRow(title: String(localized: "Last file"), value: session.lastFileName ?? String(localized: "Waiting for camera"))
            }
            .padding(14)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.05)))
        }
    }
}

private struct CameraImportSettingsSheet: View {
    @EnvironmentObject private var state: LutShopAppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Receive Format")) {
                    Picker(String(localized: "Format"), selection: $state.cameraSettings.format) {
                        ForEach(CameraImportFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "Session")) {
                    Toggle(String(localized: "Auto-create session per connection"), isOn: $state.cameraSettings.autoCreateSession)
                }

                Section(String(localized: "Files")) {
                    Toggle(String(localized: "Group RAW + JPG pairs"), isOn: $state.cameraSettings.groupRawJpgPairs)
                    Toggle(String(localized: "Skip duplicate files"), isOn: $state.cameraSettings.skipDuplicateFiles)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "Connection Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
