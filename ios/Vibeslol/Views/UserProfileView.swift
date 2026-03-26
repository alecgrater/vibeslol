import SwiftUI

struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showBlockConfirm = false

    init(userId: String) {
        _viewModel = StateObject(wrappedValue: UserProfileViewModel(userId: userId))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
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

                        // Horizontal header: avatar left, info + follow right
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

                            VStack(alignment: .leading, spacing: 8) {
                                // Username
                                Text("@\(user.username)")
                                    .font(.title3.bold())
                                    .foregroundColor(.white)

                                // Stats row
                                HStack(spacing: 20) {
                                    statItem(count: user.followingCount, label: "Following")
                                    statItem(count: user.followerCount, label: "Followers")
                                    statItem(count: user.videoCount, label: "Videos")
                                }

                                // Follow button (only for other users)
                                if AuthManager.shared.userId != user.id {
                                    Button {
                                        viewModel.toggleFollow()
                                    } label: {
                                        Text(viewModel.isFollowing ? "Following" : "Follow")
                                            .font(.caption.bold())
                                            .foregroundColor(viewModel.isFollowing ? .white : .black)
                                            .frame(width: 100, height: 30)
                                            .background(
                                                viewModel.isFollowing
                                                    ? Color.white.opacity(0.15)
                                                    : Color.vibePurple
                                            )
                                            .cornerRadius(15)
                                            .overlay(
                                                viewModel.isFollowing
                                                    ? RoundedRectangle(cornerRadius: 15)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                    : nil
                                            )
                                    }
                                }
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
                            LazyVGrid(columns: columns, spacing: 4) {
                                ForEach(viewModel.videos) { video in
                                    VideoGridCell(video: video)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal, 4)
                        }
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

            if AuthManager.shared.userId != viewModel.user?.id {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label(
                                viewModel.isBlocked ? "Unblock User" : "Block User",
                                systemImage: viewModel.isBlocked ? "hand.raised.slash" : "hand.raised"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .font(.body)
                    }
                }
            }
        }
        .alert(
            viewModel.isBlocked ? "Unblock this user?" : "Block this user?",
            isPresented: $showBlockConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button(viewModel.isBlocked ? "Unblock" : "Block", role: .destructive) {
                viewModel.toggleBlock()
            }
        } message: {
            Text(viewModel.isBlocked
                 ? "You'll start seeing their content again."
                 : "You won't see their videos in your feed. You'll also unfollow them.")
        }
        .onAppear {
            viewModel.load()
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
