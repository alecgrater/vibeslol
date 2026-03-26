import SwiftUI

struct ProfileView: View {
    @ObservedObject private var auth = AuthManager.shared

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

                        // Empty state for videos
                        if user.videoCount == 0 {
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No videos yet")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.top, 40)
                        }

                        Spacer().frame(height: 100) // tab bar clearance
                    }
                }
            } else {
                ProgressView()
                    .tint(.vibePurple)
            }
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
