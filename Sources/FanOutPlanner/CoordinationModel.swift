//  CoordinationModel.swift
//  What coordination costs, expressed as three numbers you are meant to re-measure.

import Foundation

/// The price of running a task graph across several agents instead of one.
///
/// The defaults below are seeded from published 2026 measurements, but the whole
/// point of keeping them in a struct is that they are *your* numbers to establish.
/// Run your own single-agent baseline, measure the premium and the penalty, and
/// replace these before you trust any verdict this library hands you.
public struct CoordinationModel: Sendable, Equatable {
    /// Multiplier on total token spend from inter-agent communication:
    /// re-stated context, handoff messages, the orchestrator's own reasoning.
    public let tokenPremium: Double

    /// Best-case reduction in wall-clock on genuinely parallel work. Capped by how
    /// many lanes the graph actually offers; see `effectiveParallelGain(width:)`.
    public let parallelGainCeiling: Double

    /// Wall-clock *increase* imposed on sequential work — the part of the graph that
    /// cannot fan out but still pays for handoffs, re-grounding and orchestration.
    public let sequentialPenalty: Double

    public init(tokenPremium: Double, parallelGainCeiling: Double, sequentialPenalty: Double) {
        self.tokenPremium = max(1, tokenPremium)
        self.parallelGainCeiling = min(max(0, parallelGainCeiling), 0.99)
        self.sequentialPenalty = max(0, sequentialPenalty)
    }

    /// The favourable end of the published bands.
    public static let optimistic = CoordinationModel(
        tokenPremium: 4.3, parallelGainCeiling: 0.81, sequentialPenalty: 0.39
    )

    /// The unfavourable end of the same bands. Same graph, different verdict — often.
    public static let pessimistic = CoordinationModel(
        tokenPremium: 4.6, parallelGainCeiling: 0.81, sequentialPenalty: 0.70
    )

    /// You cannot beat Amdahl by wanting to. With `width` lanes the very best you can
    /// do on the parallel portion is `1 - 1/width`, and the ceiling caps it from above.
    public func effectiveParallelGain(width: Int) -> Double {
        guard width > 1 else { return 0 }
        return min(parallelGainCeiling, 1 - 1 / Double(width))
    }

    /// The share of token volume that must be parallelisable before fan-out breaks
    /// even on wall-clock, given the lanes this graph actually offers.
    ///
    ///     (1 - p)(1 + penalty) + p(1 - gain) = 1   ⟹   p* = penalty / (penalty + gain)
    ///
    /// `tokenPremium` is deliberately absent from that expression. It is a toll, not
    /// a trade: you pay it whether or not the topology ever pays you back.
    /// Returns `nil` when the graph offers no lanes at all, because then no share of
    /// parallel work exists that could break even.
    public func breakEvenParallelShare(width: Int) -> Double? {
        let gain = effectiveParallelGain(width: width)
        guard gain > 0 else { return nil }
        return sequentialPenalty / (sequentialPenalty + gain)
    }
}
