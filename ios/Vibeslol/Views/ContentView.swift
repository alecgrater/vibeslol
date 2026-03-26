import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .feed

    enum Tab {
        case feed, discover, record, notifications, profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                switch selectedTab {
                case .feed:
                    FeedView()
                case .discover:
                    PlaceholderView(title: "Discover")
                case .record:
                    PlaceholderView(title: "Record")
                case .notifications:
                    PlaceholderView(title: "Notifications")
                case .profile:
                    PlaceholderView(title: "Profile")
                }
            }
            .ignoresSafeArea()

            // Tab bar
            TabBarView(selectedTab: $selectedTab)
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
