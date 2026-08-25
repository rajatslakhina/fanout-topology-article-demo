import XCTest
@testable import FanOutPlanner

final class TaskGraphTests: XCTestCase {

    func testChainProducesOneNodePerLevel() throws {
        let graph = try TaskGraph([
            TaskNode(id: "a", title: "A", tokens: 1),
            TaskNode(id: "b", title: "B", tokens: 1, dependsOn: ["a"]),
            TaskNode(id: "c", title: "C", tokens: 1, dependsOn: ["b"]),
        ])
        XCTAssertEqual(graph.levels.count, 3)
        XCTAssertEqual(graph.levels.map(\.count), [1, 1, 1])
    }

    func testDiamondPutsIndependentWorkOnOneLevel() throws {
        let graph = try TaskGraph([
            TaskNode(id: "root", title: "Root", tokens: 1),
            TaskNode(id: "left", title: "Left", tokens: 1, dependsOn: ["root"]),
            TaskNode(id: "right", title: "Right", tokens: 1, dependsOn: ["root"]),
            TaskNode(id: "join", title: "Join", tokens: 1, dependsOn: ["left", "right"]),
        ])
        XCTAssertEqual(graph.levels.map(\.count), [1, 2, 1])
    }

    /// A node is placed by its *longest* chain, not its shortest, or a late-arriving
    /// dependency would appear to be schedulable before the thing it waits on.
    func testNodeIsPlacedByLongestChainNotShortest() throws {
        let graph = try TaskGraph([
            TaskNode(id: "a", title: "A", tokens: 1),
            TaskNode(id: "b", title: "B", tokens: 1, dependsOn: ["a"]),
            TaskNode(id: "c", title: "C", tokens: 1, dependsOn: ["b"]),
            // Depends on both the root and the far end of the chain.
            TaskNode(id: "d", title: "D", tokens: 1, dependsOn: ["a", "c"]),
        ])
        XCTAssertEqual(graph.levels.count, 4)
        XCTAssertEqual(graph.levels[3].map(\.id), ["d"])
    }

    func testEmptyGraphIsRejected() {
        XCTAssertThrowsError(try TaskGraph([])) { error in
            XCTAssertEqual(error as? GraphError, .empty)
        }
    }

    func testDuplicateIDIsRejected() {
        let nodes = [
            TaskNode(id: "a", title: "A", tokens: 1),
            TaskNode(id: "a", title: "A again", tokens: 1),
        ]
        XCTAssertThrowsError(try TaskGraph(nodes)) { error in
            XCTAssertEqual(error as? GraphError, .duplicateID("a"))
        }
    }

    func testUnknownDependencyIsRejected() {
        let nodes = [TaskNode(id: "a", title: "A", tokens: 1, dependsOn: ["ghost"])]
        XCTAssertThrowsError(try TaskGraph(nodes)) { error in
            XCTAssertEqual(error as? GraphError, .unknownDependency(node: "a", missing: "ghost"))
        }
    }

    func testSelfDependencyIsRejected() {
        let nodes = [TaskNode(id: "a", title: "A", tokens: 1, dependsOn: ["a"])]
        XCTAssertThrowsError(try TaskGraph(nodes)) { error in
            XCTAssertEqual(error as? GraphError, .selfDependency("a"))
        }
    }

    func testCycleIsRejectedAndNamesTheNodesInvolved() {
        let nodes = [
            TaskNode(id: "root", title: "Root", tokens: 1),
            TaskNode(id: "a", title: "A", tokens: 1, dependsOn: ["b"]),
            TaskNode(id: "b", title: "B", tokens: 1, dependsOn: ["a"]),
        ]
        XCTAssertThrowsError(try TaskGraph(nodes)) { error in
            XCTAssertEqual(error as? GraphError, .cycleDetected(unresolved: ["a", "b"]))
        }
    }

    func testNegativeTokensAreClampedRatherThanTrapping() {
        XCTAssertEqual(TaskNode(id: "a", title: "A", tokens: -500).tokens, 0)
    }
}
