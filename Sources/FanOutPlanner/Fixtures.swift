//  Fixtures.swift
//  Three real shapes of agent work. The token estimates are illustrative;
//  the *shapes* are not — they are the three cases every team actually meets.

import Foundation

public enum Fixtures {
    /// The iOS inner loop. Patch, build, run the flow on a simulator, read the failure.
    /// Every step needs the output of the one before it. Width 1, all the way down.
    public static func iOSInnerLoop() -> TaskGraph {
        (try? TaskGraph([
            TaskNode(id: "patch", title: "Apply the change", tokens: 4_000),
            TaskNode(id: "build", title: "Compile the target", tokens: 6_000, dependsOn: ["patch"]),
            TaskNode(id: "verify", title: "Boot simulator, drive the UI flow", tokens: 9_000, dependsOn: ["build"]),
            TaskNode(id: "fix", title: "Read the failure, produce the next patch", tokens: 7_000, dependsOn: ["verify"]),
        ])) ?? Fixtures.fallback
    }

    /// A wide audit. One planning pass, six independent module reviews, one synthesis.
    /// This is the shape orchestration was designed for, and it is rarer than it looks.
    public static func moduleAudit() -> TaskGraph {
        var nodes = [TaskNode(id: "plan", title: "Partition the audit", tokens: 3_000)]
        let modules = ["Networking", "Persistence", "Analytics", "Payments", "Onboarding", "Search"]
        for module in modules {
            nodes.append(
                TaskNode(
                    id: "audit-\(module.lowercased())",
                    title: "Audit \(module)",
                    tokens: 12_000,
                    dependsOn: ["plan"]
                )
            )
        }
        nodes.append(
            TaskNode(
                id: "synthesis",
                title: "Merge findings into one report",
                tokens: 5_000,
                dependsOn: modules.map { "audit-\($0.lowercased())" }
            )
        )
        return (try? TaskGraph(nodes)) ?? Fixtures.fallback
    }

    /// The case that actually decides things: a spec, two independent implementations,
    /// then a sequential tail of integrate → test → fix. Half the volume is parallel.
    /// Whether this one is worth fanning out depends entirely on your coefficients.
    public static func featureShip() -> TaskGraph {
        (try? TaskGraph([
            TaskNode(id: "spec", title: "Write the spec", tokens: 5_000),
            TaskNode(id: "impl-a", title: "Implement the data layer", tokens: 14_000, dependsOn: ["spec"]),
            TaskNode(id: "impl-b", title: "Implement the view layer", tokens: 14_000, dependsOn: ["spec"]),
            TaskNode(id: "integrate", title: "Wire the layers together", tokens: 9_000, dependsOn: ["impl-a", "impl-b"]),
            TaskNode(id: "test", title: "Run the suite on device", tokens: 8_000, dependsOn: ["integrate"]),
            TaskNode(id: "repair", title: "Fix what the suite caught", tokens: 6_000, dependsOn: ["test"]),
        ])) ?? Fixtures.fallback
    }

    public static let all: [(name: String, graph: TaskGraph)] = [
        ("iOS inner loop", iOSInnerLoop()),
        ("Feature ship", featureShip()),
        ("Module audit", moduleAudit()),
    ]

    /// Unreachable in practice — `FixtureTests` asserts every fixture above validates —
    /// but it keeps these accessors non-throwing and non-trapping at every call site.
    private static let fallback: TaskGraph = {
        let single = [TaskNode(id: "unavailable", title: "Fixture unavailable", tokens: 0)]
        guard let graph = try? TaskGraph(single) else {
            preconditionFailure("A single dependency-free node is always a valid graph.")
        }
        return graph
    }()
}
