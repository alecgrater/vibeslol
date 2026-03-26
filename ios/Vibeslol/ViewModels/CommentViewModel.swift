import Foundation

@MainActor
class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var isSending = false

    let videoId: String

    init(videoId: String) {
        self.videoId = videoId
    }

    func loadComments() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                comments = try await APIClient.shared.fetchComments(videoId: videoId)
            } catch {
                print("[comments] Load error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    func postComment(text: String) {
        guard let userId = AuthManager.shared.userId else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        Task {
            do {
                let comment = try await APIClient.shared.postComment(
                    videoId: videoId, userId: userId, text: text
                )
                comments.insert(comment, at: 0)
            } catch {
                print("[comments] Post error: \(error.localizedDescription)")
            }
            isSending = false
        }
    }
}
