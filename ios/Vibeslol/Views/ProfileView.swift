import SwiftUI

struct ProfileView: View {
    @ObservedObject private var auth = AuthManager.shared
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
                    VStack(spacing: 24) {
                        Spacer().frame(height: 60)

                        // Avatar
                        Circle()
                            .fill(Color.vibePurple.opacity(0.2))
                            .frame(width: 88, height: 88)
                            .overlay(
                                Text(String(user.username.prefix(1)).uppercased())
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.vibePurple)
                            )
                            .shadow(color: .vibePurple.opacity(0.4), radius: 12)

                        // Username
                        Text("@\(user.username)")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        // Anonymous badge
                        if user.isAnonymous {
                            Text("anonymous")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                )
                        }

                        // Stats row
                        HStack(spacing: 32) {
                            statItem(count: user.followingCount, label: "Following")
                            statItem(count: user.followerCount, label: "Followers")
                            statItem(count: user.videoCount, label: "Videos")
                        }
                        .padding(.top, 8)

                        // Bio placeholder
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 24)

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

                        Spacer().frame(height: 100) // tab bar clearance
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
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

#Preview {
    ProfileView()
}
