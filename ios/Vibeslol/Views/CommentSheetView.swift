import SwiftUI

struct CommentSheetView: View {
    @StateObject private var viewModel: CommentViewModel
    @State private var newCommentText = ""
    @FocusState private var isInputFocused: Bool

    let onCommentCountChanged: (Int) -> Void

    init(videoId: String, onCommentCountChanged: @escaping (Int) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: CommentViewModel(videoId: videoId))
        self.onCommentCountChanged = onCommentCountChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // Header
            Text("\(viewModel.comments.count) comments")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            // Comments list
            if viewModel.isLoading && viewModel.comments.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Color.vibePurple)
                Spacer()
            } else if viewModel.comments.isEmpty {
                Spacer()
                Text("No comments yet")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
                Text("Be the first to comment")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }

            // Input bar
            Divider()
                .background(Color.white.opacity(0.1))

            if AuthManager.shared.currentUser?.isAnonymous == true {
                Text("Create an account to comment")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 12)
            } else {
                HStack(spacing: 10) {
                    TextField("Add a comment...", text: $newCommentText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            let text = newCommentText
                            newCommentText = ""
                            viewModel.postComment(text: text)
                            HapticsService.shared.lightTap()
                            // Update parent comment count
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onCommentCountChanged(viewModel.comments.count)
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(.vibePurple)
                        }
                        .disabled(viewModel.isSending)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .padding(.bottom, 4)
            }
        }
        .background(Color.black.opacity(0.95))
        .onAppear {
            viewModel.loadComments()
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Circle()
                .fill(Color.vibePurple.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(comment.username.prefix(1)).uppercased())
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.vibePurple)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("@\(comment.username)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.6))

                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.3))
                }

                Text(comment.text)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
        }
    }
}
