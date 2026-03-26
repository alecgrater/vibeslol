import SwiftUI

struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss

    init(userId: String) {
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userId: userId))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(.vibePurple)
            } else if let user = viewModel.user {
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 16)

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

                        // Follow button (only show for other users)
                        if AuthManager.shared.userId != user.id {
                            Button {
                                viewModel.toggleFollow()
                            } label: {
                                Text(viewModel.isFollowing ? "Following" : "Follow")
                                    .font(.subheadline.bold())
                                    .foregroundColor(viewModel.isFollowing ? .white : .black)
                                    .frame(width: 140, height: 36)
                                    .background(
                                        viewModel.isFollowing
                                            ? Color.white.opacity(0.15)
                                            : Color.vibePurple
                                    )
                                    .cornerRadius(18)
                                    .overlay(
                                        viewModel.isFollowing
                                            ? RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            : nil
                                    )
                            }
                        }

                        // Stats row
                        HStack(spacing: 32) {
                            statItem(count: user.followingCount, label: "Following")
                            statItem(count: user.followerCount, label: "Followers")
                            statItem(count: user.videoCount, label: "Videos")
                        }

                        // Bio
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

                        // Video grid
                        if viewModel.videos.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "video.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No videos yet")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(viewModel.videos) { video in
                                    VideoGridCell(video: video)
                                }
                            }
                            .padding(.horizontal, 2)
                        }

                        Spacer().frame(height: 100)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .font(.body.bold())
                }
            }
        }
        .onAppear {
            viewModel.load()
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

// MARK: - Video Grid Cell

struct VideoGridCell: View {
    let video: Video

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.vibePurple.opacity(0.1))
                .aspectRatio(9/16, contentMode: .fit)

            // Play count overlay
            HStack(spacing: 2) {
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                Text(formatCount(video.likeCount))
                    .font(.caption2.bold())
            }
            .foregroundColor(.white)
            .padding(4)
        }
        .clipped()
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
