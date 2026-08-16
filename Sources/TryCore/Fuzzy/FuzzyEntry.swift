public struct FuzzyEntry<T: Sendable>: Sendable {
    public let data: T
    public let text: String
    public let textLower: [Character]
    public let baseScore: Double

    public init(data: T, text: String, baseScore: Double) {
        self.data = data
        self.text = text
        self.textLower = Array(text.lowercased())
        self.baseScore = baseScore
    }
}
