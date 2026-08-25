import XCTest
@testable import FanOutPlanner

/// Every number quoted in the accompanying article is pinned here. If the model or the
/// fixtures move, this suite fails and the article is wrong — which is the point.
final class PublishedNumbersTests: XCTestCase {

    func testPrintPlansForTheRecord() {
        for (name, graph) in Fixtures.all {
            let m = TopologyMetrics(graph: graph)
            print("### \(name): nodes=\(m.nodeCount) depth=\(m.depth) width=\(m.maxWidth) "
                + "total=\(m.totalTokens) parallel=\(m.parallelTokens) "
                + "share=\(String(format: "%.4f", m.parallelShare)) crit=\(m.criticalPathTokens)")
            for (label, model) in [("opt", CoordinationModel.optimistic), ("pess", .pessimistic)] {
                let p = FanOutPlanner.plan(for: graph, model: model)
                print("    [\(label)] latency=\(String(format: "%.4f", p.projection.latencyIndex)) "
                    + "req=\(p.projection.requiredParallelShare.map { String(format: "%.4f", $0) } ?? "nil") "
                    + "| \(p.summary)")
            }
        }
        for width in [2, 3, 4, 6, 12] {
            let model = CoordinationModel.optimistic
            print("    width=\(width) gain=\(String(format: "%.4f", model.effectiveParallelGain(width: width))) "
                + "breakEven=\(model.breakEvenParallelShare(width: width).map { String(format: "%.4f", $0) } ?? "nil")")
        }
    }

    func testArticleSummaryLinesAreExact() {
        XCTAssertEqual(
            FanOutPlanner.plan(for: Fixtures.iOSInnerLoop()).summary,
            "Stay single-agent: the graph is a 4-step chain with no lanes. "
                + "Fan-out would cost 4.3× tokens to run 1.39× wall-clock."
        )
        XCTAssertEqual(
            FanOutPlanner.plan(for: Fixtures.moduleAudit()).summary,
            "Fan out across 6 lanes: 0.31× wall-clock for 4.3× tokens."
        )
        XCTAssertEqual(
            FanOutPlanner.plan(for: Fixtures.featureShip(), model: .pessimistic).summary,
            "Stay single-agent: 50.0% of token volume is parallelisable, break-even needs 58.3%. "
                + "Fan-out would run 1.10× wall-clock for 4.6× tokens."
        )
    }

    /// The break-even ladder the article prints. Narrower fan-out is a harder sell.
    func testBreakEvenLadder() {
        let model = CoordinationModel.optimistic
        let expected: [Int: Double] = [
            2: 0.438202, 3: 0.369085, 4: 0.342105, 6: 0.325000, 12: 0.325000,
        ]
        for (width, value) in expected {
            XCTAssertEqual(
                model.breakEvenParallelShare(width: width) ?? .nan,
                value,
                accuracy: 1e-6,
                "width \(width)"
            )
        }
    }
}
