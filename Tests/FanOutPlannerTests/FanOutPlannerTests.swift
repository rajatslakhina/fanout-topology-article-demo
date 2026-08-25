import XCTest
@testable import FanOutPlanner

final class FanOutPlannerTests: XCTestCase {

    // MARK: - The iOS inner loop

    func testInnerLoopHasNoLanesAtAll() {
        let metrics = TopologyMetrics(graph: Fixtures.iOSInnerLoop())
        XCTAssertEqual(metrics.nodeCount, 4)
        XCTAssertEqual(metrics.depth, 4)
        XCTAssertEqual(metrics.maxWidth, 1)
        XCTAssertEqual(metrics.parallelTokens, 0)
        XCTAssertEqual(metrics.parallelShare, 0)
        XCTAssertEqual(metrics.totalTokens, 26_000)
        // A chain's critical path is the whole graph.
        XCTAssertEqual(metrics.criticalPathTokens, 26_000)
    }

    func testInnerLoopStaysSingleAgentAndFanOutWouldBeSlower() {
        let plan = FanOutPlanner.plan(for: Fixtures.iOSInnerLoop())
        XCTAssertEqual(plan.verdict, .staySingleAgent(.noLanes))
        XCTAssertNil(plan.projection.requiredParallelShare)
        // Pure sequential work eats the full penalty: 1 + 0.39.
        XCTAssertEqual(plan.projection.latencyIndex, 1.39, accuracy: 1e-9)
        XCTAssertEqual(plan.projection.fanOutTokens, 111_800)
        XCTAssertEqual(plan.projection.tokenMultiple, 4.3, accuracy: 1e-9)
    }

    /// The inner loop is not a close call — it loses under every coefficient set.
    func testInnerLoopLosesUnderBothModels() {
        for model in [CoordinationModel.optimistic, .pessimistic] {
            let plan = FanOutPlanner.plan(for: Fixtures.iOSInnerLoop(), model: model)
            XCTAssertFalse(plan.shouldFanOut)
            XCTAssertGreaterThan(plan.projection.latencyIndex, 1)
        }
        // Pinned exactly, because both bounds are quoted in the article.
        XCTAssertEqual(
            FanOutPlanner.plan(for: Fixtures.iOSInnerLoop(), model: .pessimistic).projection.latencyIndex,
            1.70,
            accuracy: 1e-9
        )
    }

    // MARK: - The wide audit

    func testModuleAuditIsGenuinelyWide() {
        let metrics = TopologyMetrics(graph: Fixtures.moduleAudit())
        XCTAssertEqual(metrics.nodeCount, 8)
        XCTAssertEqual(metrics.depth, 3)
        XCTAssertEqual(metrics.maxWidth, 6)
        XCTAssertEqual(metrics.totalTokens, 80_000)
        XCTAssertEqual(metrics.parallelTokens, 72_000)
        XCTAssertEqual(metrics.parallelShare, 0.9, accuracy: 1e-9)
        // One audit lane plus the two ends, not all six lanes.
        XCTAssertEqual(metrics.criticalPathTokens, 20_000)
    }

    func testModuleAuditFansOutAndWinsDecisively() {
        let plan = FanOutPlanner.plan(for: Fixtures.moduleAudit())
        XCTAssertEqual(plan.verdict, .fanOut(lanes: 6))
        // 0.1 * 1.39 + 0.9 * 0.19
        XCTAssertEqual(plan.projection.latencyIndex, 0.31, accuracy: 1e-9)
        XCTAssertEqual(plan.projection.requiredParallelShare ?? .nan, 0.325, accuracy: 1e-9)
        XCTAssertGreaterThan(plan.metrics.parallelShare, plan.projection.requiredParallelShare ?? 1)
    }

    func testModuleAuditStillWinsUnderThePessimisticModel() {
        let plan = FanOutPlanner.plan(for: Fixtures.moduleAudit(), model: .pessimistic)
        XCTAssertTrue(plan.shouldFanOut)
    }

    // MARK: - The case that actually decides things

    func testFeatureShipSitsJustAboveBreakEvenWhenCoefficientsAreKind() {
        let plan = FanOutPlanner.plan(for: Fixtures.featureShip())
        XCTAssertEqual(plan.metrics.maxWidth, 2)
        XCTAssertEqual(plan.metrics.totalTokens, 56_000)
        XCTAssertEqual(plan.metrics.parallelTokens, 28_000)
        XCTAssertEqual(plan.metrics.parallelShare, 0.5, accuracy: 1e-9)
        XCTAssertEqual(plan.projection.requiredParallelShare ?? .nan, 0.438202, accuracy: 1e-6)
        XCTAssertEqual(plan.verdict, .fanOut(lanes: 2))
        // It "passes" — and buys 5.5% of wall-clock for 4.3x the tokens.
        XCTAssertEqual(plan.projection.latencyIndex, 0.945, accuracy: 1e-9)
    }

    /// The load-bearing result: the same graph flips verdict on the coefficients alone.
    /// This is why the library makes you supply your own, and why the honest first move
    /// is measuring a single-agent baseline rather than picking a topology.
    func testFeatureShipFlipsVerdictUnderThePessimisticModel() {
        let optimistic = FanOutPlanner.plan(for: Fixtures.featureShip(), model: .optimistic)
        let pessimistic = FanOutPlanner.plan(for: Fixtures.featureShip(), model: .pessimistic)

        XCTAssertTrue(optimistic.shouldFanOut)
        XCTAssertFalse(pessimistic.shouldFanOut)
        XCTAssertEqual(
            pessimistic.verdict,
            .staySingleAgent(.belowBreakEven(share: 0.5, required: 0.7 / 1.2))
        )
        XCTAssertEqual(pessimistic.projection.latencyIndex, 1.10, accuracy: 1e-9)
    }

    // MARK: - Invariants

    func testTokenSpendAlwaysRisesWithFanOutEvenWhenTheVerdictIsToStay() {
        for (_, graph) in Fixtures.all {
            let plan = FanOutPlanner.plan(for: graph)
            XCTAssertGreaterThan(plan.projection.fanOutTokens, plan.projection.singleAgentTokens)
        }
    }

    func testCriticalPathNeverExceedsTotalTokens() {
        for (_, graph) in Fixtures.all {
            let metrics = TopologyMetrics(graph: graph)
            XCTAssertLessThanOrEqual(metrics.criticalPathTokens, metrics.totalTokens)
        }
    }

    /// Edge case: a single node is a valid graph, has no lanes, and must not divide by zero.
    func testSingleNodeGraphIsHandled() throws {
        let graph = try TaskGraph([TaskNode(id: "only", title: "Only", tokens: 0)])
        let plan = FanOutPlanner.plan(for: graph)
        XCTAssertEqual(plan.metrics.parallelShare, 0)
        XCTAssertEqual(plan.projection.tokenMultiple, 1)
        XCTAssertEqual(plan.verdict, .staySingleAgent(.noLanes))
    }

    func testSummaryIsNonEmptyAndMentionsTheTrade() {
        for (_, graph) in Fixtures.all {
            let summary = FanOutPlanner.plan(for: graph).summary
            XCTAssertFalse(summary.isEmpty)
            XCTAssertTrue(summary.contains("tokens"))
        }
    }
}

final class FixtureTests: XCTestCase {
    /// `Fixtures` returns non-throwing graphs by falling back on a stub. Nothing should
    /// ever hit that stub, so assert every fixture is the real thing.
    func testEveryFixtureValidates() {
        XCTAssertEqual(Fixtures.all.count, 3)
        for (name, graph) in Fixtures.all {
            XCTAssertGreaterThan(graph.nodes.count, 1, "\(name) fell back to the stub graph")
            XCTAssertFalse(graph.nodes.contains { $0.id == "unavailable" }, "\(name) fell back to the stub graph")
        }
    }
}
