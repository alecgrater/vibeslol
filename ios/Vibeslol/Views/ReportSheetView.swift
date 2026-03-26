import SwiftUI

struct ReportSheetView: View {
    let videoId: String
    let onReported: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: String?
    @State private var isSubmitting = false
    @State private var showConfirmation = false

    private let reasons = [
        ("inappropriate", "Inappropriate content"),
        ("spam", "Spam or misleading"),
        ("harassment", "Harassment or bullying"),
        ("copyright", "Copyright violation"),
        ("violence", "Violence or dangerous acts"),
        ("other", "Other"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            // Header
            Text("Report Video")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.1))

            if showConfirmation {
                confirmationView
            } else {
                reasonList
            }
        }
        .background(Color.black.opacity(0.95))
    }

    private var reasonList: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Why are you reporting this video?")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ForEach(reasons, id: \.0) { reason, label in
                    Button {
                        selectedReason = reason
                        submitReport(reason: reason)
                    } label: {
                        HStack {
                            Text(label)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            if isSubmitting && selectedReason == reason {
                                ProgressView()
                                    .tint(.vibePurple)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                    .disabled(isSubmitting)

                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 20)
                }
            }
        }
    }

    private var confirmationView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.vibePurple)

            Text("Thanks for reporting")
                .font(.headline)
                .foregroundColor(.white)

            Text("We'll review this video and take action if it violates our guidelines.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.bold())
                    .foregroundColor(.black)
                    .frame(width: 120, height: 36)
                    .background(Color.vibePurple)
                    .cornerRadius(18)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func submitReport(reason: String) {
        isSubmitting = true
        Task {
            do {
                _ = try await APIClient.shared.reportVideo(videoId: videoId, reason: reason)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showConfirmation = true
                }
                onReported()
            } catch {
                print("[report] Failed: \(error.localizedDescription)")
            }
            isSubmitting = false
        }
    }
}
