import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// A library video copied into our temp directory so it survives the picker.
struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) {
            SentTransferredFile($0.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("import-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

/// Camera capture screen: live AVFoundation preview + segment recording.
/// Falls back to mock recording (timer only) on Simulator / no camera.
struct CameraView: View {
    @Environment(AppModel.self) private var model
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            HL.camBackground.ignoresSafeArea()

            if model.cameraReady {
                CameraPreviewView(session: model.camera.session)
                    .ignoresSafeArea()
            } else {
                statusMessage
            }

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
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topControls
                segmentBar
                    .padding(.top, 14)
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 20)

            if model.isImporting {
                HL.ink.opacity(0.4).ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }
        }
        .overlay(alignment: .bottom) {
            ToastView()
        }
        .onAppear { model.camera.start() }
        .onDisappear { model.camera.stop() }
        .onChange(of: pickedItem) { loadPickedItem() }
    }

    /// Routes a library selection: videos go through the 5-second gate
    /// (trim screen when longer), photos become short still clips.
    private func loadPickedItem() {
        guard let item = pickedItem else { return }
        pickedItem = nil
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        Task { @MainActor in
            if isVideo {
                if let picked = try? await item.loadTransferable(type: PickedVideo.self) {
                    model.importPickedVideo(picked.url)
                } else {
                    model.flashToast(String(localized: "Couldn't load that item"))
                }
            } else {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    model.importPickedImage(image)
                } else {
                    model.flashToast(String(localized: "Couldn't load that item"))
                }
            }
        }
    }

    /// Total recorded time against the 5-second clip cap.
    private var recordTimeLabel: String {
        let total = min(model.recordedSeconds, AppModel.maxClipSeconds)
        return "0:0\(total) / 0:0\(AppModel.maxClipSeconds)"
    }

    private var locationPillLabel: String {
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        let place = model.currentPlaceName ?? String(localized: "Locating…")
        return "\(place) · \(time)"
    }

    private var statusMessage: some View {
        VStack(spacing: 12) {
            if model.cameraPermissionDenied {
                Text("Camera access is off")
                    .font(.hl(16))
                    .foregroundStyle(.white)
                Text("Allow camera access in Settings\nto record your moments.")
                    .font(.hlRegular(13))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.hl(14))
                        .foregroundStyle(HL.ink)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background {
                            Capsule().fill(.white)
                            Capsule().strokeBorder(HL.ink, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
            } else if model.cameraUnavailable {
                Text("No camera on this device\n— recording is mocked")
                    .font(.hlRegular(13))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            } else {
                Text("Preparing camera…")
                    .font(.hlRegular(13))
                    .foregroundStyle(.white.opacity(0.35))
            }
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
                    Text(recordTimeLabel)
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
                    Text(locationPillLabel)
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

            VStack(spacing: 10) {
                cameraIconButton(systemImage: "arrow.triangle.2.circlepath.camera") {
                    model.flipCamera()
                }
                if model.cameraReady && !model.isFrontCamera {
                    cameraIconButton(
                        systemImage: model.isTorchOn ? "bolt.fill" : "bolt.slash.fill",
                        tint: model.isTorchOn ? .yellow : .white
                    ) {
                        model.toggleTorch()
                    }
                }
            }
        }
    }

    /// The full bar width represents the 5-second cap, so recorded segments
    /// (white), the in-flight segment (red), and what's left always add up.
    private var segmentBar: some View {
        let cap = CGFloat(AppModel.maxClipSeconds)
        return GeometryReader { geometry in
            let width = geometry.size.width
            HStack(spacing: 4) {
                ForEach(Array(model.segments.enumerated()), id: \.offset) { _, seconds in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(HL.ink, lineWidth: 2)
                        }
                        .frame(width: max(width * CGFloat(seconds) / cap - 4, 8))
                }
                if model.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HL.red)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white, lineWidth: 2)
                        }
                        .frame(width: max(width * CGFloat(model.elapsed) / cap - 4, 8))
                        .animation(.linear(duration: 0.3), value: model.elapsed)
                }
                if model.recordedSeconds < AppModel.maxClipSeconds {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.25))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                        }
                }
            }
        }
        .frame(height: 8)
    }

    // MARK: - Bottom

    private var bottomControls: some View {
        VStack(spacing: 18) {
            if model.cameraReady && !model.isFrontCamera {
                zoomControls
            }

            HStack {
                PhotosPicker(
                    selection: $pickedItem,
                    matching: .any(of: [.images, .videos])
                ) {
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
                }
                .buttonStyle(.plain)
                .disabled(model.isRecording)

                Spacer()

                recordButton

                Spacer()

                nextButton
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 20)
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            if model.hasUltraWide {
                zoomChip(0.5, label: ".5x")
            }
            zoomChip(1, label: "1x")
            zoomChip(2, label: "2x")
        }
    }

    private func zoomChip(_ level: CGFloat, label: String) -> some View {
        let selected = model.zoomLevel == level
        return Button {
            model.setZoom(level)
        } label: {
            Text(label)
                .font(.hl(12))
                .foregroundStyle(selected ? HL.ink : .white)
                .frame(width: 40, height: 40)
                .background {
                    Circle().fill(selected ? Color.white : HL.ink.opacity(0.45))
                    Circle().strokeBorder(
                        selected ? HL.ink : .white.opacity(0.7), lineWidth: 2
                    )
                }
        }
        .buttonStyle(.plain)
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

    private func cameraIconButton(
        systemImage: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
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
