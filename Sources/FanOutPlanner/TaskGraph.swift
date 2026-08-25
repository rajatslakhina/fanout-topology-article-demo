//  TaskGraph.swift
//  A dependency graph of agent work, and the structural facts you can read off it.

import Foundation

/// One unit of agent work: a prompt-plus-tools step with an estimated token cost.
public struct TaskNode: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    /// Estimated tokens a *single* agent spends on this step, prompt plus completion.
    public let tokens: Int
    public let dependsOn: [String]

    public init(id: String, title: String, tokens: Int, dependsOn: [String] = []) {
        self.id = id
        self.title = title
        self.tokens = max(0, tokens)
        self.dependsOn = dependsOn
    }
}

public enum GraphError: Error, Equatable, CustomStringConvertible {
    case empty
    case duplicateID(String)
    case unknownDependency(node: String, missing: String)
    case selfDependency(String)
    case cycleDetected(unresolved: [String])

    public var description: String {
        switch self {
        case .empty:
            return "A task graph needs at least one node."
        case .duplicateID(let id):
            return "Duplicate node id '\(id)'."
        case .unknownDependency(let node, let missing):
            return "Node '\(node)' depends on '\(missing)', which is not in the graph."
        case .selfDependency(let id):
            return "Node '\(id)' depends on itself."
        case .cycleDetected(let unresolved):
            return "Dependency cycle among: \(unresolved.joined(separator: ", "))."
        }
    }
}

/// A validated, acyclic graph of agent work.
///
/// Validation happens once, in `init`, so every read below is total: no throwing
/// accessors, no optionals to unwrap at the call site, and no way to hold a
/// `TaskGraph` that contains a cycle.
public struct TaskGraph: Sendable, Equatable {
    public let nodes: [TaskNode]

    /// Nodes grouped by earliest schedulable level. `levels[0]` has no dependencies;
    /// a node lands in level *i* when its longest dependency chain is *i* edges deep.
    /// Everything inside one level is mutually independent, so the count of a level
    /// is the number of agents that could genuinely work at once at that moment.
    public let levels: [[TaskNode]]

    public init(_ nodes: [TaskNode]) throws(GraphError) {
        guard !nodes.isEmpty else { throw GraphError.empty }

        var seen = Set<String>()
        for node in nodes {
            guard seen.insert(node.id).inserted else {
                throw GraphError.duplicateID(node.id)
            }
        }
        for node in nodes {
            for dependency in node.dependsOn {
                if dependency == node.id { throw GraphError.selfDependency(node.id) }
                guard seen.contains(dependency) else {
                    throw GraphError.unknownDependency(node: node.id, missing: dependency)
                }
            }
        }

        let layered = TaskGraph.layer(nodes)
        guard let levels = layered.levels else {
            // Report only the nodes Kahn's algorithm could not drain. Everything it
            // *did* drain sits outside the cycle and would be noise in the message.
            throw GraphError.cycleDetected(
                unresolved: nodes.map(\.id).filter { !layered.drained.contains($0) }.sorted()
            )
        }

        self.nodes = nodes
        self.levels = levels
    }

    /// Kahn's algorithm, carrying a longest-path depth alongside the ordering.
    /// `levels` is `nil` when the graph does not fully drain, which is exactly the
    /// condition "there is a cycle"; `drained` names everything that *did* settle,
    /// so the caller can report only the nodes genuinely caught in it.
    private static func layer(_ nodes: [TaskNode]) -> (levels: [[TaskNode]]?, drained: Set<String>) {
        var remaining: [String: Int] = [:]
        var dependents: [String: [String]] = [:]

        for node in nodes {
            remaining[node.id] = node.dependsOn.count
        }
        for node in nodes {
            for dependency in node.dependsOn {
                dependents[dependency, default: []].append(node.id)
            }
        }

        var depth: [String: Int] = [:]
        var queue: [String] = nodes.filter { $0.dependsOn.isEmpty }.map(\.id)
        for id in queue { depth[id] = 0 }

        var head = 0
        var drained = Set<String>()
        while head < queue.count {
            let id = queue[head]
            head += 1
            drained.insert(id)
            let parentDepth = depth[id] ?? 0

            for child in dependents[id] ?? [] {
                depth[child] = max(depth[child] ?? 0, parentDepth + 1)
                guard let outstanding = remaining[child] else { continue }
                remaining[child] = outstanding - 1
                if outstanding - 1 == 0 { queue.append(child) }
            }
        }

        guard drained.count == nodes.count else { return (nil, drained) }

        let deepest = depth.values.max() ?? 0
        var levels: [[TaskNode]] = Array(repeating: [], count: deepest + 1)
        for node in nodes {
            let level = depth[node.id] ?? 0
            guard levels.indices.contains(level) else { continue }
            levels[level].append(node)
        }
        return (levels, drained)
    }
}
