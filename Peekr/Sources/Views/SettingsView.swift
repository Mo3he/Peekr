import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var vm: HomeViewModel
    @AppStorage("autoRefreshInterval") private var interval: Double = 30
    @AppStorage("useLightIcon") private var useLightIcon: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var importResultMessage: String?
    @State private var showNotificationSchedules = false

    private let intervalOptions: [(label: String, seconds: Double)] = [
        ("10 seconds", 10),
        ("30 seconds", 30),
        ("1 minute",   60),
        ("2 minutes",  120),
        ("5 minutes",  300),
        ("Manual only", 0),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Auto-refresh", selection: $interval) {
                        ForEach(intervalOptions, id: \.seconds) { opt in
                            Text(opt.label).tag(opt.seconds)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Auto-Refresh Interval")
                } footer: {
                    Text("Services are checked one at a time in sequence. Use the refresh button to check all at once immediately.")
                }

                networkInfoSection

                Section("Notifications") {
                    Button {
                        showNotificationSchedules = true
                    } label: {
                        Label("Summary Notifications", systemImage: "bell.badge")
                    }
                }

                Section {
                    Toggle(isOn: $useLightIcon) {
                        Label("Light Mode Icon", systemImage: "sun.max")
                    }
                    .onChange(of: useLightIcon) { _, newVal in
                        let iconName: String? = newVal ? "AppIconLight" : nil
                        UIApplication.shared.setAlternateIconName(iconName)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Switches between the dark and light version of the app icon.")
                }

                Section("Data") {
                    if let data = vm.exportJSON() {
                        ShareLink(
                            item: data,
                            preview: SharePreview("Peekr Services", image: Image(systemName: "square.and.arrow.up"))
                        ) {
                            Label("Export Services", systemImage: "square.and.arrow.up")
                        }
                    }

                    let reportHTML = UptimeReportGenerator.generate(services: vm.services)
                    let reportFile = HTMLFile(data: reportHTML, filename: "peekr-report.html")
                    ShareLink(
                        item: reportFile,
                        preview: SharePreview("Peekr Status Report", image: Image(systemName: "chart.bar.doc.horizontal"))
                    ) {
                        Label("Export Status Report", systemImage: "chart.bar.doc.horizontal")
                    }
                    .disabled(vm.services.isEmpty)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Services", systemImage: "square.and.arrow.down")
                    }
                }

                if let msg = importResultMessage {
                    Section {
                        Text(msg)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Link(destination: URL(string: "https://www.buymeacoffee.com/mo3he")!) {
                        HStack {
                            Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showNotificationSchedules) {
                NotificationSchedulesView(vm: vm)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else {
                        importResultMessage = "Could not access the file."
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        let count = vm.importServices(from: data)
                        importResultMessage = count > 0 ? "Imported \(count) service(s)." : "No new services found."
                    } catch {
                        importResultMessage = "Import failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    importResultMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Network Info

    private var networkInfoSection: some View {
        Section {
            HStack {
                let net = NetworkMonitor.shared
                if net.isOnWiFi {
                    Label("WiFi", systemImage: "wifi")
                } else if net.likelyVPN {
                    Label("VPN", systemImage: "lock.shield")
                } else if net.isConnected {
                    Label("Cellular", systemImage: "antenna.radiowaves.left.and.right")
                } else {
                    Label("Offline", systemImage: "wifi.slash")
                }
                Spacer()
                Text(net.canReachLocal ? "Local reachable" : "Local unreachable")
                    .font(.subheadline)
                    .foregroundStyle(net.canReachLocal ? .green : .orange)
            }
        } header: {
            Text("Network")
        } footer: {
            Text("Local checks are automatically paused when your services can't be reached on the current network.")
        }
    }
}
