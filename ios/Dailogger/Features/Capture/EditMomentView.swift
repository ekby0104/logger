import SwiftUI
import SwiftData
import UIKit

struct EditMomentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var showDeleteConfirm = false

    private let moodColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    private var draftDurationLabel: String {
        if let editing = model.editingMoment {
            return editing.durationLabel
        }
        let seconds = max(model.recordedSeconds, 5)
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private var placeLabel: String {
        model.editingMoment?.placeName ?? model.currentPlaceName ?? "Locating…"
    }

    private var timeLabel: String {
        if let editing = model.editingMoment {
            return editing.createdAt.formatted(
                .dateTime.month(.abbreviated).day().hour().minute()
            )
        }
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        return String(localized: "Today · \(time)")
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        if let editing = model.editingMoment {
                            MomentThumb(moment: editing, radius: 16)
                        } else if let thumbnail = model.draftThumbnail {
                            Color.clear
                                .overlay {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(HL.ink, lineWidth: 2)
                                }
                        } else {
                            PlaceholderBox(radius: 16)
                        }
                        if model.isMerging {
                            ProgressView()
                                .tint(HL.ink)
                        }
                    }
                    .frame(width: 158, height: 280)
                    .overlay(alignment: .bottomLeading) {
                        DurBadge(text: draftDurationLabel)
                            .padding(8)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(HL.ink)
                            .offset(x: 6, y: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)

                    sectionLabel("Caption")
                    TextField(
                        "Write a line about this moment",
                        text: $model.draftCaption,
                        axis: .vertical
                    )
                    .font(.hlRegular(14.5))
                    .foregroundStyle(HL.ink)
                    .lineLimit(3...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(HL.ink, lineWidth: 2)
                    }

                    sectionLabel("Mood")
                        .padding(.top, 20)
                    LazyVGrid(columns: moodColumns, alignment: .leading, spacing: 8) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            moodChip(mood)
                        }
                    }

                    sectionLabel("Location · Time")
                        .padding(.top, 20)
                    VStack(spacing: 10) {
                        infoRow(systemImage: "mappin.and.ellipse", text: placeLabel)
                        infoRow(systemImage: "clock", text: timeLabel)
                    }

                    PrimaryButton(
                        title: String(localized: "Save to timeline"),
                        systemImage: "checkmark",
                        height: 54
                    ) {
                        model.saveMoment(context: context)
                    }
                    .disabled(model.isMerging)
                    .opacity(model.isMerging ? 0.6 : 1)
                    .padding(.top, 24)

                    if model.editingMoment != nil {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Delete moment")
                                    .font(.hl(15))
                            }
                            .foregroundStyle(HL.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(HL.ink, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                        .confirmationDialog(
                            "Delete this moment?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) {
                                if let moment = model.editingMoment {
                                    model.deleteMoment(moment, context: context)
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This removes the clip and its thumbnail.")
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(HL.paper.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button {
                model.closeOverlay()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HL.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Edit moment")
                .font(.hl(17))
                .foregroundStyle(HL.ink)

            Spacer()

            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            HL.paper
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HL.ink).frame(height: 2)
                }
        }
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.hl(14))
            .foregroundStyle(HL.ink)
            .padding(.bottom, 8)
    }

    private func moodChip(_ mood: Mood) -> some View {
        let selected = mood == model.draftMood
        return Button {
            model.draftMood = mood
        } label: {
            Text(mood.displayName)
                .font(.hl(14))
                .foregroundStyle(selected ? .white : HL.ink)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .frame(maxWidth: .infinity)
                .background {
                    ZStack {
                        if selected {
                            Capsule().fill(HL.ink).offset(x: 3, y: 3)
                        }
                        Capsule().fill(selected ? HL.purple : Color.white)
                        Capsule().strokeBorder(HL.ink, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func infoRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
            Text(text)
                .font(.hl(14))
            Spacer(minLength: 0)
        }
        .foregroundStyle(HL.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(HL.ink, lineWidth: 2)
        }
    }
}
