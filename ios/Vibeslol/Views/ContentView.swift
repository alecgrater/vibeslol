import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .feed

    enum Tab {
        case feed, discover, record, notifications, profile
    }

    var body: some View {
        ZStack {
            // Main content — no bottom tab bar, navigation lives in FeedView top bar
            Group {
                switch selectedTab {
                case .feed:
                    FeedView(selectedTab: $selectedTab)
                case .discover:
                    PlaceholderView(title: "Discover")
                case .record:
                    CameraView()
                case .notifications:
                    PlaceholderView(title: "Notifications")
                case .profile:
                    ProfileView(selectedTab: $selectedTab)
                }
            }
            .ignoresSafeArea()
        }
        .background(Color.black)
    }
}

struct PlaceholderView: View {
    let title: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(title)
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

#Preview {
    ContentView()
}
