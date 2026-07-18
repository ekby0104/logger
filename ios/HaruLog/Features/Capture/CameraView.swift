import SwiftUI

/// Camera capture screen.
/// Phase 4 scaffold: full UI + record state machine with a mock preview.
/// Real AVFoundation capture lands in Phase 5 (CameraKit).
struct CameraView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            HL.camBackground.ignoresSafeArea()

            LinearGradient(
                stops: [
                    .init(color: HL.ink.opacity(0.5), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.6),
                    .init(color: HL.ink.opacity(0.8), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Text("Camera preview\n(AVFoundation — Phase 5)")
                .font(.hlRegular(13))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)

            VStack(spacing: 0) {
                topControls
                segmentBar
                    .padding(.top, 14)
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottom) {
            ToastView()
        }
    }

    // MARK: - Top

    private var topControls: some View {
        HStack(alignment: .top) {
            cameraIconButton(systemImage: "xmark") {
                model.closeOverlay()
            }

            Spacer()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.isRecording ? HL.red : Color.white.opacity(0.6))
                        .frame(width: 10, height: 10)
                    Text(model.elapsedLabel)
                        .font(.hl(15))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(HL.ink.opacity(0.6))
                    Capsule().strokeBorder(.white, lineWidth: 2)
                }

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold))
                    Text("Seongsu, Seoul · 8:12 PM")
                        .font(.hl(12))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(HL.ink.opacity(0.5))
                    Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 2)
                }
            }

            Spacer()

            cameraIconButton(systemImage: "arrow.triangle.2.circlepath.camera") {
                model.flipCamera()
            }
        }
    }

    private var segmentBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(model.segments.enumerated()), id: \.offset) { _, seconds in
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(HL.ink, lineWidth: 2)
                    }
                    .frame(width: CGFloat(min(seconds * 7, 60)), height: 8)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                }
                .frame(height: 8)
        }
    }

    // MARK: - Bottom

    private var bottomControls: some View {
        VStack(spacing: 18) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        moodChip(mood)
                    }
                }
            }
            .scrollIndicators(.hidden)

            HStack {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(HL.ink.opacity(0.5))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white, lineWidth: 2)
                    }

                Spacer()

                recordButton

                Spacer()

                nextButton
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 20)
    }

    private var recordButton: some View {
        Button {
            model.toggleRecord()
        } label: {
            ZStack {
                Circle()
                    .fill(HL.ink.opacity(0.35))
                    .overlay {
                        Circle().strokeBorder(.white, lineWidth: 5)
                    }
                    .frame(width: 82, height: 82)

                RoundedRectangle(
                    cornerRadius: model.isRecording ? 7 : 30,
                    style: .continuous
                )
                .fill(HL.red)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: model.isRecording ? 7 : 30,
                        style: .continuous
                    )
                    .strokeBorder(.white, lineWidth: 2)
                }
                .frame(
                    width: model.isRecording ? 26 : 60,
                    height: model.isRecording ? 26 : 60
                )
            }
            .animation(.easeInOut(duration: 0.2), value: model.isRecording)
        }
        .buttonStyle(.plain)
    }

    private var nextButton: some View {
        let enabled = model.recordedSeconds > 0
        return Button {
            model.goToEdit()
        } label: {
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(enabled ? HL.ink : .white.opacity(0.5))
                .frame(width: 50, height: 50)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(enabled ? Color.white : HL.ink.opacity(0.35))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            enabled ? Color.white : .white.opacity(0.6),
                            lineWidth: 2
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func moodChip(_ mood: Mood) -> some View {
        let selected = mood == model.draftMood
        return Button {
            model.draftMood = mood
        } label: {
            Text(mood.rawValue)
                .font(.hl(14))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background {
                    Capsule().fill(selected ? HL.purple : HL.ink.opacity(0.45))
                    Capsule().strokeBorder(.white, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private func cameraIconButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(HL.ink.opacity(0.5))
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
    }
}
