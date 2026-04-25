import SwiftUI

struct NotificationSchedulesView: View {
    @ObservedObject var vm: HomeViewModel
    @State private var schedules: [MetricSummarySchedule] = []
    @State private var editingSchedule: MetricSummarySchedule?
    @State private var showingAdd = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if schedules.isEmpty {
                    ContentUnavailableView(
                        "No Notification Schedules",
                        systemImage: "bell.slash",
                        description: Text("Add a schedule to receive periodic summaries of your service metrics.")
                    )
                } else {
                    ForEach(schedules) { schedule in
                        scheduleRow(schedule)
                    }
                    .onDelete { indices in
                        schedules.remove(atOffsets: indices)
                        SummaryNotificationManager.shared.schedules = schedules
                    }
                }

                Section {
                    Text("Summary notifications show live metrics for a service at a scheduled time. They work even when the app is closed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Summary Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                MetricSummaryEditView(vm: vm, existing: nil) { newSchedule in
                    schedules.append(newSchedule)
                    SummaryNotificationManager.shared.schedules = schedules
                }
            }
            .sheet(item: $editingSchedule) { schedule in
                MetricSummaryEditView(vm: vm, existing: schedule) { updated in
                    if let idx = schedules.firstIndex(where: { $0.id == updated.id }) {
                        schedules[idx] = updated
                        SummaryNotificationManager.shared.schedules = schedules
                    }
                }
            }
            .onAppear {
                schedules = SummaryNotificationManager.shared.schedules
            }
        }
    }

    private func scheduleRow(_ schedule: MetricSummarySchedule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.serviceName)
                    .font(.headline)
                    .foregroundStyle(schedule.isEnabled ? .primary : .secondary)
                Text(schedule.scheduleType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !schedule.metricLabels.isEmpty {
                    Text(schedule.metricLabels.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { newVal in
                    if let idx = schedules.firstIndex(where: { $0.id == schedule.id }) {
                        schedules[idx].isEnabled = newVal
                        SummaryNotificationManager.shared.schedules = schedules
                    }
                }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { editingSchedule = schedule }
    }
}

// MARK: - Edit / Create Sheet

struct MetricSummaryEditView: View {
    @ObservedObject var vm: HomeViewModel
    let existing: MetricSummarySchedule?
    let onSave: (MetricSummarySchedule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedServiceID: UUID?
    @State private var selectedMetricLabels: Set<String> = []
    @State private var scheduleType: ScheduleTypeOption = .daily
    @State private var dailyHour: Int = 9
    @State private var dailyMinute: Int = 0
    @State private var intervalHours: Int = 4
    @State private var dailyTime: Date = {
        var c = DateComponents(); c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    @ObservedObject private var live = LiveDataStore.shared

    enum ScheduleTypeOption: String, CaseIterable {
        case daily = "Daily at time"
        case interval = "Every N hours"
    }

    var selectedService: Service? {
        guard let id = selectedServiceID else { return nil }
        return vm.services.first { $0.id == id }
    }

    var availableMetrics: [ServiceMetric] {
        guard let id = selectedServiceID else { return [] }
        return live.metrics[id] ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                // Service picker
                Section("Service") {
                    Picker("Service", selection: $selectedServiceID) {
                        Text("Select a service").tag(UUID?.none)
                        ForEach(vm.services) { svc in
                            Text(svc.name).tag(UUID?.some(svc.id))
                        }
                    }
                }

                // Schedule type
                Section("Schedule") {
                    Picker("Type", selection: $scheduleType) {
                        ForEach(ScheduleTypeOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)

                    if scheduleType == .daily {
                        DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                    } else {
                        Stepper("Every \(intervalHours) hour\(intervalHours == 1 ? "" : "s")",
                                value: $intervalHours, in: 1...24)
                    }
                }

                // Metric picker
                if !availableMetrics.isEmpty {
                    Section {
                        ForEach(availableMetrics) { metric in
                            HStack {
                                Image(systemName: metric.icon)
                                    .foregroundStyle(metric.color)
                                    .frame(width: 22)
                                Text(metric.label)
                                Spacer()
                                if selectedMetricLabels.contains(metric.label) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedMetricLabels.contains(metric.label) {
                                    selectedMetricLabels.remove(metric.label)
                                } else {
                                    selectedMetricLabels.insert(metric.label)
                                }
                            }
                        }
                    } header: {
                        Text("Metrics to include")
                    } footer: {
                        Text(selectedMetricLabels.isEmpty ? "All metrics will be included (up to 5)." : "\(selectedMetricLabels.count) selected.")
                    }
                } else if selectedServiceID != nil {
                    Section {
                        Label("Refresh the service first to load its metrics.", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let svc = selectedService else { return }
                        let cal = Calendar.current
                        let type: MetricSummarySchedule.ScheduleType
                        if scheduleType == .daily {
                            type = .daily(
                                hour: cal.component(.hour, from: dailyTime),
                                minute: cal.component(.minute, from: dailyTime)
                            )
                        } else {
                            type = .interval(hours: intervalHours)
                        }
                        var schedule = existing ?? MetricSummarySchedule(
                            serviceID: svc.id,
                            serviceName: svc.name,
                            metricLabels: [],
                            scheduleType: type
                        )
                        schedule.serviceID = svc.id
                        schedule.serviceName = svc.name
                        schedule.metricLabels = Array(selectedMetricLabels)
                        schedule.scheduleType = type
                        onSave(schedule)
                        dismiss()
                    }
                    .disabled(selectedServiceID == nil)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let e = existing else { return }
        selectedServiceID = e.serviceID
        selectedMetricLabels = Set(e.metricLabels)
        switch e.scheduleType {
        case .daily(let h, let m):
            scheduleType = .daily
            let cal = Calendar.current
            dailyTime = cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
        case .interval(let h):
            scheduleType = .interval
            intervalHours = h
        }
    }
}
