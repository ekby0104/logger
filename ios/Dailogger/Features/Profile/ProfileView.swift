import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @Query private var moments: [Moment]
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showFontPicker = false
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileHandle") private var profileHandle = ""
    @AppStorage(ReminderService.enabledKey) private var reminderEnabled = false

    private let archiveColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var streak: Int {
        Stats.streak(recordDates: logs.map(\.date) + moments.map(\.createdAt))
    }

    private var blogCount: Int {
        logs.filter { $0.blogText != nil }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 22)

                statsCard
                    .padding(.bottom, 24)

                HStack {
                    Text("Past daily blogs")
                        .font(.hl(16))
                        .foregroundStyle(HL.ink)
                    Spacer()
                    Text("\(logs.count) total")
                        .font(.hl(12.5))
                        .foregroundStyle(HL.gray)
                }
                .padding(.bottom, 12)

                if logs.isEmpty {
                    Text("Your daily blogs will appear here.")
                        .font(.hlRegular(13))
                        .foregroundStyle(HL.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                } else {
                    LazyVGrid(columns: archiveColumns, spacing: 8) {
                        ForEach(logs) { log in
                            archiveCell(log)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(HL.placeholder)
                .overlay {
                    Circle().strokeBorder(HL.ink, lineWidth: 2)
                }
                .overlay {
                    Image(systemName: "person")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(HL.ink)
                }
                .frame(width: 64, height: 64)
                .background {
                    Circle().fill(HL.ink).offset(x: 3, y: 3)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(profileName.isEmpty ? String(localized: "My Days") : profileName)
                    .font(.hl(19))
                    .foregroundStyle(HL.ink)
                Text(profileHandle.isEmpty ? "@my.daily" : profileHandle)
                    .font(.hlRegular(13))
                    .foregroundStyle(HL.gray)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HL.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .hardCard(radius: 12, shadowOffset: 3)
            .confirmationDialog("Settings", isPresented: $showSettings) {
                Button("Edit profile") {
                    showEditProfile = true
                }
                Button("Change font") {
                    showFontPicker = true
                }
                if reminderEnabled {
                    Button("Turn off daily reminder") {
                        reminderEnabled = false
                        ReminderService.reschedule(hasMomentToday: false)
                        model.flashToast(String(localized: "Daily reminder is off"))
                    }
                } else {
                    Button("Turn on daily reminder (9 PM)") {
                        enableReminder()
                    }
                }
                Button("Remove sample data", role: .destructive) {
                    removeSampleData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes the demo moments (no video) and past demo days. Your real recordings and blogs stay.")
            }
            .sheet(isPresented: $showEditProfile) {
                ProfileEditSheet()
                    .presentationDetents([.height(340)])
            }
            .confirmationDialog("Change font", isPresented: $showFontPicker) {
                Button("Handwriting (KwonJungae)") { setFont(.kwonjungae) }
                Button("Typewriter") { setFont(.typewriter) }
                Button("System default") { setFont(.system) }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func setFont(_ choice: HLFontChoice) {
        UserDefaults.standard.set(choice.rawValue, forKey: HLFontChoice.storageKey)
        WidgetBridge.syncFontChoice(choice.rawValue)
        model.flashToast(String(localized: "Font changed"))
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(streak)", label: "Streak")
            statItem(value: "\(blogCount)", label: "Blogs")
            statItem(value: "\(moments.count)", label: "Moments")
        }
        .padding(.vertical, 16)
        .hardCard(radius: 16)
    }

    private func statItem(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.hl(23))
                .foregroundStyle(HL.ink)
            Text(label)
                .font(.hlRegular(12))
                .foregroundStyle(HL.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func archiveCell(_ log: DailyLog) -> some View {
        Button {
            model.openBlog(log)
        } label: {
            archiveCellContent(log)
        }
        .buttonStyle(.plain)
    }

    /// A clip from the log's day to represent it in the archive grid —
    /// prefers one that actually has a thumbnail file.
    private func dayThumbnailMoment(_ log: DailyLog) -> Moment? {
        let calendar = Calendar.current
        let dayMoments = moments.filter { calendar.isDate($0.createdAt, inSameDayAs: log.date) }
        return dayMoments.first { $0.thumbnailFileName != nil } ?? dayMoments.first
    }

    private func archiveCellContent(_ log: DailyLog) -> some View {
        Group {
            if let moment = dayThumbnailMoment(log) {
                MomentThumb(moment: moment, radius: 12)
            } else {
                PlaceholderBox(radius: 12)
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .overlay(alignment: .bottomLeading) {
            Text(log.dayLabel)
                .font(.hl(12))
                .foregroundStyle(HL.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(HL.ink, lineWidth: 1.5)
                }
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            Text("\(log.clipCount) clips")
                .font(.hl(10))
                .foregroundStyle(HL.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(HL.ink, lineWidth: 1.5)
                }
                .padding(6)
        }
    }

    private func enableReminder() {
        Task { @MainActor in
            if await ReminderService.requestAuthorization() {
                reminderEnabled = true
                model.refreshWidgetAndReminder(context: context)
                model.flashToast(String(localized: "Daily reminder is on"))
            } else {
                model.flashToast(String(localized: "Allow notifications in Settings"))
            }
        }
    }

    /// Deletes seeded demo content: moments without a recorded clip and
    /// past days that never got a blog. Real recordings are untouched.
    private func removeSampleData() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        for moment in moments where moment.videoFileName == nil {
            context.delete(moment)
        }
        for log in logs where log.blogText == nil && log.date < todayStart {
            context.delete(log)
        }
        UserDefaults.standard.set(true, forKey: SeedData.samplesRemovedKey)
        model.flashToast(String(localized: "Sample data removed"))
    }
}

// MARK: - Profile edit sheet

private struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = ""
    @AppStorage("profileHandle") private var profileHandle = ""
    @State private var name = ""
    @State private var handle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit profile")
                .font(.hl(18))
                .foregroundStyle(HL.ink)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 20)

            fieldLabel("Name")
            styledField(String(localized: "My Days"), text: $name)
                .padding(.bottom, 16)

            fieldLabel("Handle")
            styledField("@my.daily", text: $handle)
                .padding(.bottom, 24)

            PrimaryButton(title: String(localized: "Save"), systemImage: "checkmark") {
                profileName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                profileHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(HL.paper.ignoresSafeArea())
        .onAppear {
            name = profileName
            handle = profileHandle
        }
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.hl(14))
            .foregroundStyle(HL.ink)
            .padding(.bottom, 8)
    }

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.hlRegular(15))
            .foregroundStyle(HL.ink)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(HL.ink, lineWidth: 2)
            }
    }
}
