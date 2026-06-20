import SwiftUI

/// Wake-up Check mission: "STILL AWAKE?" — the user types the shown word, and each letter
/// bolds as it's correctly typed. Completes once the whole word matches.
struct TypeWordMissionView: View {
    let word: String
    let onMissionComplete: () -> Void

    @State private var typed = ""
    @FocusState private var focused: Bool

    /// Number of leading characters typed correctly so far (case-insensitive).
    private var matchedCount: Int {
        let target = Array(word.lowercased())
        let input = Array(typed.lowercased())
        var n = 0
        while n < input.count && n < target.count && input[n] == target[n] { n += 1 }
        return n
    }

    var body: some View {
        ZStack {
            Color(hex: "F2F2F7").ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text("☀️")
                    .font(.system(size: 88))

                Text("STILL AWAKE?")
                    .font(.system(size: 16, weight: .bold))
                    .tracking(3)
                    .foregroundColor(Color(hex: "999999"))

                // The word, bolding letter-by-letter as it's typed.
                HStack(spacing: 1) {
                    ForEach(Array(word.enumerated()), id: \.offset) { idx, ch in
                        Text(String(ch))
                            .font(.system(size: 52, weight: idx < matchedCount ? .bold : .regular))
                            .foregroundColor(idx < matchedCount ? Color(hex: "1A1A1A") : Color(hex: "C7C7CC"))
                    }
                }
                .animation(.easeOut(duration: 0.1), value: matchedCount)

                Text("Type the word above")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "999999"))

                Spacer()

                // Invisible field that drives the keyboard + captures keystrokes.
                TextField("", text: $typed)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .opacity(0.02)
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }   // tap anywhere to re-focus if the keyboard drops
        .onAppear { focused = true }
        .onChange(of: typed) { _ in
            if matchedCount == word.count {
                onMissionComplete()
            }
        }
    }
}
