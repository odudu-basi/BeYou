import Foundation

/// One "why do you feel this way?" option: its text, emoji, and the affirmation
/// categories it maps to (drives both the AI prompt and the offline fallback).
struct MoodReasonOption: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let emoji: String
    let categories: [String]
}

/// 15 reasons per mood. The intervention shows 5 random ones each time.
enum MoodReasonLibrary {

    static func randomReasons(for mood: MentalHealthMood, count: Int = 5) -> [MoodReasonOption] {
        Array(reasons(for: mood).shuffled().prefix(count))
    }

    static func reasons(for mood: MentalHealthMood) -> [MoodReasonOption] {
        switch mood {
        case .great:      return great
        case .good:       return good
        case .okay:       return okay
        case .notGreat:   return notGreat
        case .struggling: return struggling
        }
    }

    private static let great: [MoodReasonOption] = [
        .init(text: "Feeling confident in myself", emoji: "💪", categories: ["Confidence", "Feeling sassy"]),
        .init(text: "Excited about my future", emoji: "🚀", categories: ["Dream big", "Purpose"]),
        .init(text: "Grateful for the people in my life", emoji: "💛", categories: ["Gratitude", "Romance"]),
        .init(text: "Riding a wave of good energy", emoji: "✨", categories: ["Positivity", "Attraction"]),
        .init(text: "Just feeling like that girl/guy", emoji: "💅", categories: ["Feeling sassy", "Confidence"]),
        .init(text: "Proud of how far I've come", emoji: "🏆", categories: ["Confidence", "Gratitude"]),
        .init(text: "In love with my life right now", emoji: "🥰", categories: ["Gratitude", "Positivity"]),
        .init(text: "Unstoppable and full of drive", emoji: "🔥", categories: ["Purpose", "Dream big"]),
        .init(text: "Glowing inside and out", emoji: "🌟", categories: ["Self-love", "Feeling sassy"]),
        .init(text: "Ready to take on anything", emoji: "💥", categories: ["Confidence", "Purpose"]),
        .init(text: "Dreaming big and believing it", emoji: "🌠", categories: ["Dream big", "Purpose"]),
        .init(text: "Feeling magnetic and attractive", emoji: "🧲", categories: ["Attraction", "Confidence"]),
        .init(text: "Thankful for this moment", emoji: "🙏", categories: ["Gratitude", "Positivity"]),
        .init(text: "Living in my main-character era", emoji: "🎬", categories: ["Feeling sassy", "Confidence"]),
        .init(text: "Surrounded by good energy", emoji: "🌈", categories: ["Positivity", "Attraction"]),
    ]

    private static let good: [MoodReasonOption] = [
        .init(text: "Today's a good day", emoji: "☀️", categories: ["Morning", "Positivity"]),
        .init(text: "Feeling positive about things", emoji: "🌱", categories: ["Positivity", "Gratitude"]),
        .init(text: "Making progress on my goals", emoji: "📈", categories: ["Purpose", "Dream big"]),
        .init(text: "Feeling connected to people I love", emoji: "🤝", categories: ["Romance", "Gratitude"]),
        .init(text: "In a calm, peaceful headspace", emoji: "🧘", categories: ["Self-love", "Positivity"]),
        .init(text: "Quietly content with where I am", emoji: "😌", categories: ["Gratitude", "Self-love"]),
        .init(text: "Hopeful about what's ahead", emoji: "🌤", categories: ["Dream big", "Positivity"]),
        .init(text: "Feeling balanced and steady", emoji: "⚖️", categories: ["Self-talk", "Positivity"]),
        .init(text: "Grateful for the little things", emoji: "🌼", categories: ["Gratitude", "Inner child"]),
        .init(text: "Motivated to keep going", emoji: "🏃", categories: ["Purpose", "Confidence"]),
        .init(text: "Comfortable being myself", emoji: "💗", categories: ["Self-love", "Confidence"]),
        .init(text: "Open to good things coming", emoji: "🍀", categories: ["Attraction", "Positivity"]),
        .init(text: "Feeling rested and clear", emoji: "🧠", categories: ["Self-talk", "Morning"]),
        .init(text: "Appreciating the people around me", emoji: "🫶", categories: ["Romance", "Gratitude"]),
        .init(text: "Trusting the process", emoji: "🌊", categories: ["Purpose", "Self-talk"]),
    ]

    private static let okay: [MoodReasonOption] = [
        .init(text: "Just getting through the day", emoji: "🚶", categories: ["Self-love", "Positivity"]),
        .init(text: "Feeling a bit flat", emoji: "😶", categories: ["Positivity", "Inner child"]),
        .init(text: "Not bad, just not great either", emoji: "🤷", categories: ["Self-talk", "Gratitude"]),
        .init(text: "A little distracted or restless", emoji: "💭", categories: ["Self-talk", "Purpose"]),
        .init(text: "Could use a pick-me-up", emoji: "☕", categories: ["Positivity", "Confidence"]),
        .init(text: "Running on autopilot", emoji: "🔁", categories: ["Self-talk", "Purpose"]),
        .init(text: "A little tired but okay", emoji: "😴", categories: ["Self-love", "Morning"]),
        .init(text: "Looking for some motivation", emoji: "🔎", categories: ["Purpose", "Dream big"]),
        .init(text: "Feeling kind of meh", emoji: "😑", categories: ["Positivity", "Inner child"]),
        .init(text: "Need to reset my mind", emoji: "🔄", categories: ["Self-talk", "Overthinking"]),
        .init(text: "Going through the motions", emoji: "🎭", categories: ["Purpose", "Self-love"]),
        .init(text: "Craving a bit of joy", emoji: "🎈", categories: ["Inner child", "Positivity"]),
        .init(text: "Stuck in a slow day", emoji: "🐌", categories: ["Positivity", "Self-love"]),
        .init(text: "Quietly hoping for better", emoji: "🌥", categories: ["Dream big", "Positivity"]),
        .init(text: "Just need a little spark", emoji: "⚡", categories: ["Confidence", "Positivity"]),
    ]

    private static let notGreat: [MoodReasonOption] = [
        .init(text: "Low energy or motivation", emoji: "🔋", categories: ["Purpose", "Positivity"]),
        .init(text: "Comparing myself to others", emoji: "📱", categories: ["Self-love", "Overthinking"]),
        .init(text: "Feeling not good enough", emoji: "🪞", categories: ["Self-love", "Confidence"]),
        .init(text: "Stressed about life", emoji: "😤", categories: ["Anxiety", "Self-talk"]),
        .init(text: "Just having a rough day", emoji: "🌧️", categories: ["Self-love", "Gratitude"]),
        .init(text: "Overwhelmed by my to-do list", emoji: "📋", categories: ["Anxiety", "Self-talk"]),
        .init(text: "Doubting myself", emoji: "😟", categories: ["Confidence", "Self-love"]),
        .init(text: "Feeling behind in life", emoji: "⏳", categories: ["Purpose", "Self-love"]),
        .init(text: "Drained and worn out", emoji: "🪫", categories: ["Self-love", "Positivity"]),
        .init(text: "Frustrated with myself", emoji: "😮‍💨", categories: ["Self-talk", "Self-love"]),
        .init(text: "Can't seem to focus", emoji: "🌀", categories: ["Overthinking", "Self-talk"]),
        .init(text: "Missing my motivation", emoji: "💤", categories: ["Purpose", "Dream big"]),
        .init(text: "Feeling a little down", emoji: "🌫", categories: ["Self-love", "Positivity"]),
        .init(text: "Worried about the future", emoji: "😬", categories: ["Anxiety", "Dream big"]),
        .init(text: "Just not feeling myself", emoji: "🥀", categories: ["Self-love", "Inner child"]),
    ]

    private static let struggling: [MoodReasonOption] = [
        .init(text: "Feeling anxious or overwhelmed", emoji: "😰", categories: ["Anxiety", "Self-love"]),
        .init(text: "Constantly comparing myself to others", emoji: "📱", categories: ["Self-love", "Overthinking"]),
        .init(text: "Feeling like I'm not good enough", emoji: "🪞", categories: ["Self-love", "Confidence"]),
        .init(text: "Lonely or disconnected", emoji: "🫂", categories: ["Romance", "Inner child"]),
        .init(text: "Stuck in negative thoughts", emoji: "🌀", categories: ["Overthinking", "Self-talk"]),
        .init(text: "Everything feels like too much", emoji: "🌊", categories: ["Anxiety", "Self-love"]),
        .init(text: "Can't quiet my racing mind", emoji: "🧠", categories: ["Overthinking", "Anxiety"]),
        .init(text: "Feeling lost right now", emoji: "🧭", categories: ["Purpose", "Self-love"]),
        .init(text: "Heavy-hearted and tired", emoji: "💔", categories: ["Self-love", "Inner child"]),
        .init(text: "Like I'm not enough", emoji: "🥀", categories: ["Self-love", "Confidence"]),
        .init(text: "Afraid I'm falling behind", emoji: "⏳", categories: ["Anxiety", "Self-love"]),
        .init(text: "Overthinking everything", emoji: "🔁", categories: ["Overthinking", "Self-talk"]),
        .init(text: "Needing some comfort", emoji: "🧸", categories: ["Inner child", "Self-love"]),
        .init(text: "Drowning in stress", emoji: "😵‍💫", categories: ["Anxiety", "Self-talk"]),
        .init(text: "Just want to feel okay again", emoji: "🌦", categories: ["Self-love", "Positivity"]),
    ]
}
