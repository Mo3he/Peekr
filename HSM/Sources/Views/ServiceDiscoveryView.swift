import SwiftUI

/// Presented as a sheet from ServicePickerView. Scans the local network for known
/// self-hosted services via mDNS/Bonjour and lets the user tap one to pre-fill
/// AddServiceView with the detected type, host, and port.
struct ServiceDiscoveryView: View {
    /// Passed in from ServicePickerView so results survive sheet dismissal.
    @ObservedObject var discovery: NetworkDiscoveryService

    /// Called when the user selects a discovered service.
    /// serviceType is nil for unidentified (Generic) services so AddServiceView
    /// lets the user pick the type freely while still pre-filling host and port.
    let onSelect: (ServiceType?, String, Int) -> Void

    @Environment(\..dismiss) private var dismiss
    @ObservedObject private var store = ServiceStore.shared

    // MARK: - Scan mode

    private enum ScanMode: String, CaseIterable {
        case auto     = "Auto"
        case ipRange  = "IP Range"
    }

    @State private var scanMode: ScanMode = .auto
    @State private var ipRangeText: String = ""
    @State private var showIPRangeError = false

    /// Results with already-added services filtered out (matched on host + port).
    private var filteredResults: [DiscoveredNetworkService] {
        let existing = Set(store.services.map { "\($0.host):\($0.port)" })
        return discovery.results.filter { !existing.contains("\($0.host):\($0.port)") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredResults.isEmpty || discovery.isScanning {
                    emptyState
                } else {
                    resultsList
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                scanModeHeader
            }
            .navigationTitle("Network Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if discovery.isScanning {
                        ProgressView()
                    } else {
                        Button(scanMode == .auto ? "Scan Again" : "Scan") {
                            startCurrentScan()
                        }
                        .disabled(scanMode == .ipRange && ipRangeText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            // Only auto-start when in Auto mode on the very first open.
            if scanMode == .auto && discovery.results.isEmpty && !discovery.isScanning {
                discovery.startScan()
            }
        }
        .onDisappear { discovery.stopScan() }
    }

    // MARK: - Scan Mode Header

    @ViewBuilder
    private var scanModeHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Scan Mode", selection: $scanMode) {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .onChange(of: scanMode) { _, newMode in
                showIPRangeError = false
                discovery.stopScan()
                discovery.resetResults()
                if newMode == .auto {
                    discovery.startScan()
                }
            }

            if scanMode == .ipRange {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("e.g. 192.168.10.0/24 or 10.0.10.1-254", text: $ipRangeText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: ipRangeText) { _, _ in showIPRangeError = false }
                            .onSubmit { startCurrentScan() }

                        if !ipRangeText.isEmpty {
                            Button {
                                ipRangeText = ""
                                showIPRangeError = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    if showIPRangeError {
                        Text("Invalid range. Try 192.168.10.0/24 or 10.0.10.1-254.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 10)
            }

            Divider()
        }
        .background(.bar)
    }

    // MARK: - Scan trigger

    private func startCurrentScan() {
        showIPRangeError = false
        switch scanMode {
        case .auto:
            discovery.startScan()
        case .ipRange:
            let trimmed = ipRangeText.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            guard NetworkDiscoveryService.parseIPRange(trimmed) != nil else {
                showIPRangeError = true
                return
            }
            discovery.startScan(ipRange: trimmed)
        }
    }

    // MARK: - Empty / Scanning State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            if discovery.isScanning {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning your network...")
                    .font(.headline)
                if discovery.scanProgress > 0 {
                    ProgressView(value: discovery.scanProgress)
                        .padding(.horizontal, 40)
                    Text("\(Int(discovery.scanProgress * 100))% scanned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Looking for Home Assistant, Plex, Jellyfin, and more.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else if scanMode == .ipRange && discovery.results.isEmpty {
                Image(systemName: "network")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Enter an IP range")
                    .font(.headline)
                Text("Type a CIDR block or range above, then tap Scan to search a different subnet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No services found")
                    .font(.headline)
                Text("Make sure you're on the same Wi-Fi network as your self-hosted services.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Scan Again") { startCurrentScan() }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
            Spacer()
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(filteredResults) { service in
            Button {
                dismiss()
                onSelect(service.serviceType == .generic ? nil : service.serviceType, service.host, service.port)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemFill))
                            .frame(width: 44, height: 44)
                        Image(systemName: service.serviceType.icon)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 18, weight: .medium))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(service.host + ":" + String(service.port))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(service.serviceType.displayName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        if service.serviceType == .generic {
                            Text("Tap to identify")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
