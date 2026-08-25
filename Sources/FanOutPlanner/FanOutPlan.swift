//  FanOutPlan.swift
//  The verdict: fan out, or establish the single-agent baseline and stop talking about it.

import Foundation

public enum StayReason: Sendable, Equatable {
    /// Every level holds one node. The graph is a chain; there is nothing to fan out to.
    case noLanes
    /// There are lanes, but not enough token volume runs through them.
    case belowBreakEven(share: Double, required: Double)
}

public enum Verdict: Sendable, Equatable {
    case staySingleAgent(StayReason)
    case fanOut(lanes: Int)
}

/// Both sides of the trade, in units you can compare.
public struct Projection: Sendable, Equatable {
    public let singleAgentTokens: Int
    public let fanOutTokens: Int
    /// Fan-out wall-clock, with single-agent normalised to 1.0.
    /// Below 1.0 is faster; above 1.0 means coordination cost you time as well as money.
    public let latencyIndex: Double
    public let observedParallelShare: Double
    public let requiredParallelShare: Double?

    /// Extra tokens burned, as a plain multiple. Always ≥ 1.
    public var tokenMultiple: Double {
        guard singleAgentTokens > 0 else { return 1 }
        return Double(fanOutTokens) / Double(singleAgentTokens)
    }
}

public struct FanOutPlan: Sendable, Equatable {
    public let metrics: TopologyMetrics
    public let model: CoordinationModel
    public let projection: Projection
    public let verdict: Verdict

    public var shouldFanOut: Bool {
        if case .fanOut = verdict { return true }
        return false
    }

    /// One line you could paste into a planning doc without editing it.
    public var summary: String {
        let tokens = String(format: "%.1f", projection.tokenMultiple)
        let latency = String(format: "%.2f", projection.latencyIndex)
        switch verdict {
        case .fanOut(let lanes):
            return "Fan out across \(lanes) lanes: \(latency)× wall-clock for \(tokens)× tokens."
        case .staySingleAgent(.noLanes):
            return "Stay single-agent: the graph is a \(metrics.depth)-step chain with no lanes. "
                 + "Fan-out would cost \(tokens)× tokens to run \(latency)× wall-clock."
        case .staySingleAgent(.belowBreakEven(let share, let required)):
            let have = String(format: "%.0f%%", share * 100)
            let need = String(format: "%.0f%%", required * 100)
            return "Stay single-agent: \(have) of token volume is parallelisable, "
                 + "break-even needs \(need). Fan-out would run \(latency)× wall-clock for \(tokens)× tokens."
        }
    }
}

public enum FanOutPlanner {
    /// Reads the topology, prices the coordination, and returns the trade.
    ///
    /// The decision rule is one comparison — is projected wall-clock actually below
    /// the single-agent baseline — and it deliberately ignores `tokenPremium`, because
    /// spending more tokens is never itself a reason to fan out.
    public static func plan(
        for graph: TaskGraph,
        model: CoordinationModel = .optimistic
    ) -> FanOutPlan {
        let metrics = TopologyMetrics(graph: graph)
        let width = metrics.maxWidth
        let gain = model.effectiveParallelGain(width: width)
        let required = model.breakEvenParallelShare(width: width)

        let p = metrics.parallelShare
        let sequential = 1 - p

        // The token premium never enters here.
        // Spending more does not buy wall-clock.
        let latencyIndex = sequential * (1 + model.sequentialPenalty) + p * (1 - gain)

        let projection = Projection(
            singleAgentTokens: metrics.totalTokens,
            fanOutTokens: Int((Double(metrics.totalTokens) * model.tokenPremium).rounded()),
            latencyIndex: latencyIndex,
            observedParallelShare: p,
            requiredParallelShare: required
        )

        let verdict: Verdict
        if let required {
            verdict = latencyIndex < 1
                ? .fanOut(lanes: width)
                : .staySingleAgent(.belowBreakEven(share: p, required: required))
        } else {
            verdict = .staySingleAgent(.noLanes)
        }

        return FanOutPlan(metrics: metrics, model: model, projection: projection, verdict: verdict)
    }
}
//  FanOutPlan.swift
//  The verdict: fan out, or establish the single-agent baseline and stop talking about it.

import Foundation

public enum StayReason: Sendable, Equatable {
    /// Every level holds one node. The graph is a chain; there is nothing to fan out to.
    case noLanes
    /// There are lanes, but not enough token volume runs through them.
    case belowBreakEven(share: Double, required: Double)
}

public enum Verdict: Sendable, Equatable {
    case staySingleAgent(StayReason)
    case fanOut(lanes: Int)
}

/// Both sides of the trade, in units you can compare.
public struct Projection: Sendable, Equatable {
    public let singleAgentTokens: Int
    public let fanOutTokens: Int
    /// Fan-out wall-clock, with single-agent normalised to 1.0.
    /// Below 1.0 is faster; above 1.0 means coordination cost you time as well as money.
    public let latencyIndex: Double
    public let observedParallelShare: Double
    public let requiredParallelShare: Double?

    /// Extra tokens burned, as a plain multiple. Always ≥ 1.
    public var tokenMultiple: Double {
        guard singleAgentTokens > 0 else { return 1 }
        return Double(fanOutTokens) / Double(singleAgentTokens)
    }
}

public struct FanOutPlan: Sendable, Equatable {
    public let metrics: TopologyMetrics
    public let model: CoordinationModel
    public let projection: Projection
    public let verdict: Verdict

    public var shouldFanOut: Bool {
        if case .fanOut = verdict { return true }
        return false
    }

    /// One line you could paste into a planning doc without editing it.
    public var summary: String {
        let tokens = String(format: "%.1f", projection.tokenMultiple)
        let latency = String(format: "%.2f", projection.latencyIndex)
        switch verdict {
        case .fanOut(let lanes):
            return "Fan out across \(lanes) lanes: \(latency)× wall-clock for \(tokens)× tokens."
        case .staySingleAgent(.noLanes):
            return "Stay single-agent: the graph is a \(metrics.depth)-step chain with no lanes. "
                 + "Fan-out would cost \(tokens)× tokens to run \(latency)× wall-clock."
        case .staySingleAgent(.belowBreakEven(let share, let required)):
            let have = String(format: "%.0f%%", share * 100)
            let need = String(format: "%.0f%%", required * 100)
            return "Stay single-agent: \(have) of token volume is parallelisable, "
                 + "break-even needs \(need). Fan-out would run \(latency)× wall-clock for \(tokens)× tokens."
        }
    }
}

public enum FanOutPlanner {
    /// Reads the topology, prices the coordination, and returns the trade.
    ///
    /// The decision rule is one comparison — is projected wall-clock actually below
    /// the single-agent baseline — and it deliberately ignores `tokenPremium`, because
    /// spending more tokens is never itself a reason to fan out.
    public static func plan(
        for graph: TaskGraph,
        model: CoordinationModel = .optimistic
    ) -> FanOutPlan {
        let metrics = TopologyMetrics(graph: graph)
        let width = metrics.maxWidth
        let gain = model.effectiveParallelGain(width: width)
        let required = model.breakEvenParallelShare(width: width)

        let p = metrics.parallelShare
        let sequential = 1 - p
        let latencyIndex = sequential * (1 + model.sequentialPenalty) + p * (1 - gain)

        let projection = Projection(
            singleAgentTokens: metrics.totalTokens,
            fanOutTokens: Int((Double(metrics.totalTokens) * model.tokenPremium).rounded()),
            latencyIndex: latencyIndex,
            observedParallelShare: p,
            requiredParallelShare: required
        )

        let verdict: Verdict
        if let required {
            verdict = latencyIndex < 1
                ? .fanOut(lanes: width)
                : .staySingleAgent(.belowBreakEven(share: p, required: required))
        } else {
            verdict = .staySingleAgent(.noLanes)
        }

        return FanOutPlan(metrics: metrics, model: model, projection: projection, verdict: verdict)
    }
}
