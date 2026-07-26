import XCTest
@testable import LightsOutCore

final class FrictionEscalationTests: XCTestCase {

    private let delays = [60, 180, 600]

    // MARK: - delaySeconds

    func testDelay_firstOverride_usesFirstDelay() {
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 0, delays: delays), 60)
    }

    func testDelay_escalatesWithEachGrant() {
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 1, delays: delays), 180)
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 2, delays: delays), 600)
    }

    func testDelay_pastEnd_clampsToHarshestRatherThanWrapping() {
        // Running off the end must not fall back to the *cheapest* delay.
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 3, delays: delays), 600)
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 99, delays: delays), 600)
    }

    func testDelay_emptyDelays_usesDefault() {
        XCTAssertEqual(
            FrictionEscalation.delaySeconds(grantedTonight: 0, delays: []),
            FrictionEscalation.defaultDelaySeconds
        )
    }

    func testDelay_negativeCount_treatedAsFirst() {
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: -1, delays: delays), 60)
    }

    func testDelay_singleDelay_alwaysThatDelay() {
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 0, delays: [30]), 30)
        XCTAssertEqual(FrictionEscalation.delaySeconds(grantedTonight: 5, delays: [30]), 30)
    }

    // MARK: - isEmergency

    func testEmergency_notTriggeredWhileOrdinaryOverridesRemain() {
        for granted in 0..<delays.count {
            XCTAssertFalse(
                FrictionEscalation.isEmergency(grantedTonight: granted, delays: delays, phase: .windDown),
                "granted=\(granted) should still be an ordinary override"
            )
        }
    }

    func testEmergency_triggeredOnceOverridesExhausted() {
        XCTAssertTrue(
            FrictionEscalation.isEmergency(grantedTonight: 3, delays: delays, phase: .windDown)
        )
    }

    func testEmergency_lightsOutIsAlwaysEmergency() {
        XCTAssertTrue(
            FrictionEscalation.isEmergency(grantedTonight: 0, delays: delays, phase: .lightsOut)
        )
    }

    func testEmergency_amberFollowsTheCounter() {
        XCTAssertFalse(
            FrictionEscalation.isEmergency(grantedTonight: 0, delays: delays, phase: .amber)
        )
        XCTAssertTrue(
            FrictionEscalation.isEmergency(grantedTonight: 3, delays: delays, phase: .amber)
        )
    }

    func testEmergency_emptyDelaysMeansNoOrdinaryOverridesAtAll() {
        XCTAssertTrue(
            FrictionEscalation.isEmergency(grantedTonight: 0, delays: [], phase: .amber)
        )
    }

    // MARK: - remainingOrdinaryOverrides

    func testRemaining_countsDown() {
        XCTAssertEqual(FrictionEscalation.remainingOrdinaryOverrides(grantedTonight: 0, delays: delays), 3)
        XCTAssertEqual(FrictionEscalation.remainingOrdinaryOverrides(grantedTonight: 2, delays: delays), 1)
        XCTAssertEqual(FrictionEscalation.remainingOrdinaryOverrides(grantedTonight: 3, delays: delays), 0)
    }

    func testRemaining_neverNegative() {
        XCTAssertEqual(FrictionEscalation.remainingOrdinaryOverrides(grantedTonight: 99, delays: delays), 0)
    }

    // MARK: - Phase layering

    func testPhaseLayering_lightsOutKeepsEarlierPhasesInForce() {
        XCTAssertTrue(Phase.amber.isInForce(whenCurrentIs: .lightsOut))
        XCTAssertTrue(Phase.windDown.isInForce(whenCurrentIs: .lightsOut))
        XCTAssertTrue(Phase.lightsOut.isInForce(whenCurrentIs: .lightsOut))
    }

    func testPhaseLayering_laterPhasesNotInForceEarly() {
        XCTAssertTrue(Phase.amber.isInForce(whenCurrentIs: .amber))
        XCTAssertFalse(Phase.windDown.isInForce(whenCurrentIs: .amber))
        XCTAssertFalse(Phase.lightsOut.isInForce(whenCurrentIs: .amber))
    }

    func testPhaseLayering_idleHoldsNothing() {
        XCTAssertFalse(Phase.amber.isInForce(whenCurrentIs: .idle))
        XCTAssertFalse(Phase.idle.isInForce(whenCurrentIs: .lightsOut))
    }
}
