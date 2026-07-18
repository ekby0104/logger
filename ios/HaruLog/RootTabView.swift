import SwiftUI
import SwiftData

struct RootTabView: View {
    @State private var model = AppModel()
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack(alignment: .bottom) {
            HL.paper.ignoresSafeArea()

            Group {
                switch model.tab {
                case .today: TodayView()
                case .timeline: TimelineView()
                case .calendar: CalendarView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar()
        }
        .fullScreenCover(item: $model.overlay) { overlay in
            Group {
                switch overlay {
                case .camera: CameraView()
                case .edit: EditMomentView()
                case .viewer: MomentViewerView()
                }
            }
            .environment(model)
        }
        .overlay(alignment: .bottom) {
            ToastView()
        }
        .environment(model)
        .task {
            SeedData.insertIfNeeded(context: context)
        }
    }
}

// MARK: - Custom tab bar with center record FAB

private struct TabBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tabButton(.today, icon: "house", label: "Today")
            tabButton(.timeline, icon: "list.bullet", label: "Timeline")

            VStack {
                Button {
                    model.openCamera()
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
                .hardCard(fill: HL.blue, radius: 28, shadowOffset: 4)
                .offset(y: -14)
            }
            .frame(maxWidth: .infinity)

            tabButton(.calendar, icon: "calendar", label: "Calendar")
            tabButton(.profile, icon: "person", label: "Me")
        }
        .padding(.top, 9)
        .padding(.horizontal, 6)
        .background {
            Rectangle()
                .fill(.white)
                .overlay(alignment: .top) {
                    Rectangle().fill(HL.ink).frame(height: 2)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ tab: AppModel.Tab, icon: String, label: String) -> some View {
        Button {
            model.tab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                Text(label)
                    .font(.hl(10.5))
            }
            .foregroundStyle(model.tab == tab ? HL.blue : HL.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Moment.self, DailyLog.self], inMemory: true)
}
