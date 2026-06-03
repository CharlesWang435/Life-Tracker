import SwiftUI
import UIKit
import UserNotifications
import LifeTrackerCore

/// App settings, organized by purpose: reminders, what you track, and about.
/// Future per-feature preferences (goals, weekly review, etc.) get their own sections here.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(ReflectionNotifications.Defaults.enabled) private var reflectionEnabled = true
    @AppStorage(ReflectionNotifications.Defaults.hour) private var reflectionHour = 20
    @AppStorage(ReflectionNotifications.Defaults.minute) private var reflectionMinute = 0

    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    @AppStorage("capture.noteOnStop") private var noteOnStop = false

    @AppStorage(UntrackedNotifications.Defaults.enabled) private var untrackedEnabled = false
    @AppStorage(UntrackedNotifications.Defaults.hour) private var untrackedHour = 21
    @AppStorage(UntrackedNotifications.Defaults.minute) private var untrackedMinute = 0

    @AppStorage(WeeklyReviewNotifications.Defaults.enabled) private var weeklyEnabled = false
    @AppStorage(WeeklyReviewNotifications.Defaults.weekday) private var weeklyWeekday = 1
    @AppStorage(WeeklyReviewNotifications.Defaults.hour) private var weeklyHour = 18
    @AppStorage(WeeklyReviewNotifications.Defaults.minute) private var weeklyMinute = 0

    private var weeklyTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: weeklyHour, minute: weeklyMinute, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                weeklyHour = comps.hour ?? 18
                weeklyMinute = comps.minute ?? 0
                rescheduleWeekly()
            }
        )
    }

    private var untrackedTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: untrackedHour, minute: untrackedMinute, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                untrackedHour = comps.hour ?? 21
                untrackedMinute = comps.minute ?? 0
                rescheduleUntracked()
            }
        )
    }

    /// OS-level notification permission. Loaded on appear and refreshed when the app
    /// returns to the foreground (e.g. after the user changes it in iOS Settings).
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    /// True when the OS will actually deliver a scheduled reminder.
    private var notificationsAllowed: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }

    /// Bridges the stored hour/minute to the `DatePicker`'s `Date` binding, anchored to
    /// today so the produced date is always valid.
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reflectionHour, minute: reflectionMinute, second: 0, of: .now
                ) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reflectionHour = components.hour ?? 20
                reflectionMinute = components.minute ?? 0
                reschedule()
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                reflectionSection
                captureSection
                weeklySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshNotificationStatus() } }
            }
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $appearanceRaw) {
                ForEach(AppAppearance.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option.rawValue)
                }
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Automatic follows your device's light/dark setting.")
        }
    }

    private var reflectionSection: some View {
        Section {
            Toggle("Evening reflection reminder", isOn: $reflectionEnabled)
                .onChange(of: reflectionEnabled) { _, isOn in handleReminderToggle(isOn) { reschedule() } }

            if reflectionEnabled {
                DatePicker(
                    "Remind me at",
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )

                if !notificationsAllowed && notificationStatus != .notDetermined {
                    permissionWarning
                }
            }
        } header: {
            Text("Reflection")
        } footer: {
            Text("A nightly nudge to log how your day felt. Tapping it opens today's reflection.")
        }
    }

    private var captureSection: some View {
        Section {
            Toggle("Ask for a note when stopping", isOn: $noteOnStop)

            Toggle("End-of-day untracked reminder", isOn: $untrackedEnabled)
                .onChange(of: untrackedEnabled) { _, isOn in handleReminderToggle(isOn) { rescheduleUntracked() } }
            if untrackedEnabled {
                DatePicker("Remind me at", selection: untrackedTime, displayedComponents: .hourAndMinute)
                if !notificationsAllowed && notificationStatus != .notDetermined {
                    permissionWarning
                }
            }
        } header: {
            Text("Logging")
        } footer: {
            Text("Jot a note when you stop a timer, and get a nightly nudge to fill in any untracked time.")
        }
    }

    private func rescheduleUntracked() {
        UntrackedNotifications.reschedule(enabled: untrackedEnabled, hour: untrackedHour, minute: untrackedMinute)
    }

    private var weeklySection: some View {
        Section {
            Toggle("Weekly review reminder", isOn: $weeklyEnabled)
                .onChange(of: weeklyEnabled) { _, isOn in handleReminderToggle(isOn) { rescheduleWeekly() } }
            if weeklyEnabled {
                DatePicker("Sunday at", selection: weeklyTime, displayedComponents: .hourAndMinute)
                if !notificationsAllowed && notificationStatus != .notDetermined {
                    permissionWarning
                }
            }
        } header: {
            Text("Weekly review")
        } footer: {
            Text("A Sunday recap of your week — time tracked, trends, mood, and highlights.")
        }
    }

    private func rescheduleWeekly() {
        WeeklyReviewNotifications.reschedule(enabled: weeklyEnabled, weekday: weeklyWeekday, hour: weeklyHour, minute: weeklyMinute)
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
        }
    }

    /// Shown when the reminder is enabled in-app but the OS won't deliver it.
    private var permissionWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Notifications are turned off for Tempo", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
            Text("Your reminder won't be delivered until you allow notifications for Tempo in iOS Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open iOS Settings") { openSystemSettings() }
                .font(.caption.weight(.semibold))
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    // MARK: Actions

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    /// When a reminder is switched on we request permission first (if undecided) and only
    /// then schedule — so a fresh user doesn't end up with a toggle that silently does
    /// nothing, and scheduling reflects the real authorization state.
    private func handleReminderToggle(_ isOn: Bool, reschedule: @escaping () -> Void) {
        guard isOn else { reschedule(); return }
        Task {
            if notificationStatus == .notDetermined {
                await ReflectionNotifications.requestAuthorizationGranted()
                await refreshNotificationStatus()
            }
            reschedule()
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await ReflectionNotifications.authorizationStatus()
    }

    private func reschedule() {
        ReflectionNotifications.reschedule(
            enabled: reflectionEnabled,
            hour: reflectionHour,
            minute: reflectionMinute
        )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SettingsView()
}
