// ChatView.swift
// In-game chat with text messages and emoji quick-sends

import SwiftUI

struct ChatView: View {

    @ObservedObject var viewModel: GameViewModel
    @State private var messageText = ""
    @FocusState private var isFieldFocused: Bool
    @State private var showEmojiPicker = false

    private let quickEmojis = ["👍", "😄", "😱", "🎲", "🏆", "💀", "🔥", "❤️", "😎", "🤣"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.gameState.chatMessages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.gameState.chatMessages.count) { _ in
                        if let last = viewModel.gameState.chatMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Quick emoji row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickEmojis, id: \.self) { emoji in
                            Button {
                                viewModel.sendChatMessage(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(.regularMaterial)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                Divider()

                // Text input
                HStack(spacing: 10) {
                    TextField("Message...", text: $messageText)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.regularMaterial)
                        )
                        .focused($isFieldFocused)
                        .onSubmit { sendMessage() }

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(messageText.isEmpty ? .secondary : .accentColor)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        viewModel.sendChatMessage(text)
        messageText = ""
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    private var isOwnMessage: Bool {
        message.playerID == AuthService.shared.currentUserID
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage { Spacer(minLength: 60) }

            if !isOwnMessage {
                Circle()
                    .fill(message.playerColor.swiftUIColor)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(message.playerName.prefix(1))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 3) {
                if !isOwnMessage {
                    Text(message.playerName)
                        .font(.caption2)
                        .foregroundStyle(message.playerColor.swiftUIColor)
                }

                if message.isEmoji {
                    Text(message.content)
                        .font(.system(size: 40))
                } else {
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundStyle(isOwnMessage ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isOwnMessage ? Color.accentColor : Color(.secondarySystemBackground))
                        )
                }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if isOwnMessage {
                Circle()
                    .fill(message.playerColor.swiftUIColor)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(message.playerName.prefix(1))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }

            if !isOwnMessage { Spacer(minLength: 60) }
        }
    }
}
