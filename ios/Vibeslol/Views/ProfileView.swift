import SwiftUI

struct ProfileView: View {
    @ObservedObject private var auth = AuthManager.shared
    @Binding var selectedTab: ContentView.Tab
    @State private var userVideos: [Video] = []
    @State private var isLoadingVideos = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let user = auth.currentUser {
                ScrollView {
                    VStack(spacing: 20) {
                        // Close / back button row
                        HStack {
                            Button {
                                selectedTab = .feed
                                HapticsService.shared.lightTap()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.body.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)

                        // Horizontal header: avatar left, info right
                        HStack(spacing: 16) {
                            // Avatar
                            Circle()
                                .fill(Color.vibePurple.opacity(0.2))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Text(String(user.username.prefix(1)).uppercased())
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.vibePurple)
                                )
                                .shadow(color: .vibePurple.opacity(0.4), radius: 12)

                            VStack(alignment: .leading, spacing: 6) {
                                // Username
                                Text("@\(user.username)")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)

                                // Anonymous badge
                                if user.isAnonymous {
                                    Text("anonymous")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.08))
                                        )
                                }

                                // Stats row
                                HStack(spacing: 20) {
                                    statItem(count: user.followingCount, label: "Following")
                                    statItem(count: user.followerCount, label: "Followers")
                                    statItem(count: user.videoCount, label: "Videos")
                                }
                                .padding(.top, 2)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        // Bio
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 16)

                        // Video grid or empty state
                        if userVideos.isEmpty && !isLoadingVideos {
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No videos yet")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.top, 40)
                        } else if isLoadingVideos {
                            ProgressView()
                                .tint(.vibePurple)
                                .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(userVideos) { video in
                                    VideoGridCell(video: video)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
                .onAppear {
                    loadUserVideos()
                }
            } else {
                ProgressView()
                    .tint(.vibePurple)
            }
        }
    }

    private func loadUserVideos() {
        guard let userId = auth.userId else { return }
        isLoadingVideos = true
        Task {
            do {
                userVideos = try await APIClient.shared.fetchUserVideos(userId: userId)
            } catch {
                print("[profile] Failed to load videos: \(error.localizedDescription)")
            }
            isLoadingVideos = false
        }
    }

    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

#Preview {
    ProfileView(selectedTab: .constant(.profile))
}
