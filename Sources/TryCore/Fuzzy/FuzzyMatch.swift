public struct FuzzyMatch<T: Sendable>: Sendable {
    public let data: T
    public let text: String
    public let positions: [Int]
    public let score: Double
}
