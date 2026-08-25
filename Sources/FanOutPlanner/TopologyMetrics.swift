//  TopologyMetrics.swift
//  The structural facts that decide fan-out, read off the graph and nothing else.

import Foundation

public struct TopologyMetrics: Sendable, Equatable {
    public let nodeCount: Int
    public let totalTokens: Int
    /// Number of dependency levels. This is the length of the longest chain, in steps.
    public let depth: Int
    /// The widest level. This is the ceiling on how many agents can ever be busy at once.
    public let maxWidth: Int
    /// Tokens sitting on levels that hold more than one node, i.e. genuinely fan-out-able work.
    public let parallelTokens: Int
    /// Longest path through the graph weighted by tokens: the floor on wall-clock,
    /// no matter how many agents you throw at it.
    public let criticalPathTokens: Int

    /// The fraction of total token volume that is genuinely parallelisable.
    /// This is the only input to the break-even test that comes from your work
    /// rather than from the coordination overhead.
    public var parallelShare: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(parallelTokens) / Double(totalTokens)
    }

    public init(graph: TaskGraph) {
        let nodes = graph.nodes
        self.nodeCount = nodes.count
        self.totalTokens = nodes.reduce(0) { $0 + $1.tokens }
        self.depth = graph.levels.count
        self.maxWidth = graph.levels.map(\.count).max() ?? 0
        self.parallelTokens = graph.levels
            .filter { $0.count > 1 }
            .reduce(0) { total, level in total + level.reduce(0) { $0 + $1.tokens } }
        self.criticalPathTokens = TopologyMetrics.criticalPath(graph)
    }

    private static func criticalPath(_ graph: TaskGraph) -> Int {
        var cost: [String: Int] = [:]
        // `graph.levels` is already a valid topological order, so one forward pass
        // is enough: every dependency of a node sits in a strictly earlier level.
        for level in graph.levels {
            for node in level {
                let inherited = node.dependsOn.reduce(0) { max($0, cost[$1] ?? 0) }
                cost[node.id] = inherited + node.tokens
            }
        }
        return cost.values.max() ?? 0
    }
}
