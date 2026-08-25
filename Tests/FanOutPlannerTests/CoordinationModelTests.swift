import XCTest
@testable import FanOutPlanner

final class CoordinationModelTests: XCTestCase {

    func testWidthOneOffersNoGain() {
        XCTAssertEqual(CoordinationModel.optimistic.effectiveParallelGain(width: 1), 0)
        XCTAssertEqual(CoordinationModel.optimistic.effectiveParallelGain(width: 0), 0)
    }

    /// Amdahl caps narrow fan-out well below the published ceiling.
    func testNarrowFanOutIsCappedByLaneCountNotByTheCeiling() {
        let model = CoordinationModel.optimistic
        XCTAssertEqual(model.effectiveParallelGain(width: 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(model.effectiveParallelGain(width: 4), 0.75, accuracy: 1e-9)
        // 1 - 1/6 = 0.8333, above the 0.81 ceiling, so the ceiling wins.
        XCTAssertEqual(model.effectiveParallelGain(width: 6), 0.81, accuracy: 1e-9)
    }

    func testBreakEvenIsUndefinedWithoutLanes() {
        XCTAssertNil(CoordinationModel.optimistic.breakEvenParallelShare(width: 1))
    }

    /// p* = penalty / (penalty + gain).
    func testBreakEvenMatchesTheClosedForm() {
        let model = CoordinationModel.optimistic
        // width 6 -> gain 0.81 -> 0.39 / 1.20
        XCTAssertEqual(model.breakEvenParallelShare(width: 6) ?? .nan, 0.325, accuracy: 1e-9)
        // width 2 -> gain 0.50 -> 0.39 / 0.89
        XCTAssertEqual(model.breakEvenParallelShare(width: 2) ?? .nan, 0.438202, accuracy: 1e-6)
    }

    /// The headline structural claim: narrower fan-out demands *more* parallel work.
    func testNarrowerFanOutRequiresAHigherParallelShare() {
        let model = CoordinationModel.optimistic
        let two = model.breakEvenParallelShare(width: 2) ?? 0
        let six = model.breakEvenParallelShare(width: 6) ?? 0
        XCTAssertGreaterThan(two, six)
    }

    /// The token premium never appears in the break-even. Going from 4.3x to 44x moves nothing.
    func testTokenPremiumDoesNotMoveTheBreakEven() {
        let cheap = CoordinationModel(tokenPremium: 4.3, parallelGainCeiling: 0.81, sequentialPenalty: 0.39)
        let dear = CoordinationModel(tokenPremium: 44.0, parallelGainCeiling: 0.81, sequentialPenalty: 0.39)
        XCTAssertEqual(
            cheap.breakEvenParallelShare(width: 6) ?? .nan,
            dear.breakEvenParallelShare(width: 6) ?? .nan,
            accuracy: 1e-12
        )
    }

    func testPessimisticPenaltyRaisesTheBar() {
        let optimistic = CoordinationModel.optimistic.breakEvenParallelShare(width: 2) ?? 0
        let pessimistic = CoordinationModel.pessimistic.breakEvenParallelShare(width: 2) ?? 0
        XCTAssertGreaterThan(pessimistic, optimistic)
        XCTAssertEqual(pessimistic, 0.583333, accuracy: 1e-6)
    }

    func testTokenPremiumIsClampedToAtLeastOne() {
        let model = CoordinationModel(tokenPremium: 0.2, parallelGainCeiling: 0.5, sequentialPenalty: 0.1)
        XCTAssertEqual(model.tokenPremium, 1)
    }
}
