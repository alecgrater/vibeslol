import SwiftUI

struct TabBarView: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(icon: "house", tab: .feed)
            tabButton(icon: "magnifyingglass", tab: .discover)
            recordButton
            tabButton(icon: "bell", tab: .notifications)
            tabButton(icon: "person", tab: .profile)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func tabButton(icon: String, tab: ContentView.Tab) -> some View {
        Button {
            selectedTab = tab
            HapticsService.shared.lightTap()
        } label: {
            Image(systemName: selectedTab == tab ? "\(icon).fill" : icon)
                .font(.title3)
                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.4))
                .shadow(color: selectedTab == tab ? .vibePurple.opacity(0.5) : .clear, radius: 6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private var recordButton: some View {
        Button {
            selectedTab = .record
            HapticsService.shared.mediumTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.vibePurple.opacity(0.8))
                    .frame(width: 44, height: 32)
                    .shadow(color: .vibePurple.opacity(0.4), radius: 8)

                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}
