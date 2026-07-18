import SwiftUI
import UIKit

// MARK: - Hard card (neo-brutal: white fill, ink border, hard offset shadow)

struct HardCardStyle: ViewModifier {
    var fill: Color = .white
    var radius: CGFloat = 16
    var borderWidth: CGFloat = 2
    var shadowOffset: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(HL.ink)
                        .offset(x: shadowOffset, y: shadowOffset)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(fill)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(HL.ink, lineWidth: borderWidth)
                }
            }
    }
}

extension View {
    func hardCard(
        fill: Color = .white,
        radius: CGFloat = 16,
        borderWidth: CGFloat = 2,
        shadowOffset: CGFloat = 6
    ) -> some View {
        modifier(HardCardStyle(
            fill: fill,
            radius: radius,
            borderWidth: borderWidth,
            shadowOffset: shadowOffset
        ))
    }
}

// MARK: - Placeholder media box

struct PlaceholderBox: View {
    var radius: CGFloat = 11

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(HL.placeholder)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(HL.ink, lineWidth: 2)
            }
    }
}

// MARK: - Moment thumbnail (real frame if available, placeholder otherwise)

struct MomentThumb: View {
    let moment: Moment
    var radius: CGFloat = 11

    var body: some View {
        if let url = moment.thumbnailURL,
           let image = UIImage(contentsOfFile: url.path) {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(HL.ink, lineWidth: 2)
                }
        } else {
            PlaceholderBox(radius: radius)
        }
    }
}

// MARK: - Empty state

struct EmptyMomentsCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(HL.muted)
            Text("No moments yet today")
                .font(.hl(15))
                .foregroundStyle(HL.ink)
            Text("Tap the record button below to capture your first moment.")
                .font(.hlRegular(13))
                .foregroundStyle(HL.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(HL.muted, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
        }
    }
}

// MARK: - Pills & badges

struct MoodPill: View {
    let mood: Mood

    var body: some View {
        Text(mood.displayName)
            .font(.hl(11))
            .foregroundStyle(HL.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay {
                Capsule().strokeBorder(HL.purple, lineWidth: 1.5)
            }
    }
}

struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HL.purple)
            Text("\(days) days")
                .font(.hl(14))
                .foregroundStyle(HL.ink)
        }
        .padding(.horizontal, 13)
        .frame(height: 34)
        .hardCard(radius: 17, shadowOffset: 3)
    }
}

struct DurBadge: View {
    let text: String

    var body: some View {
        Text(text)
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
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    let systemImage: String
    var height: CGFloat = 48
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.hl(16))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(.plain)
        .hardCard(fill: HL.blue, radius: 12, shadowOffset: 4)
    }
}

// MARK: - Toast

struct ToastView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let toast = model.toast {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 17, weight: .bold))
                    Text(toast)
                        .font(.hl(14))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(HL.purple)
                            .offset(x: 5, y: 5)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(HL.ink)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 94)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: model.toast)
    }
}
