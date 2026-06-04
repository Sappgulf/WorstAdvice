import XCTest
@testable import Badvice

final class GenerationLoadingMessageProviderTests: XCTestCase {
    func testLoadingMessagesAreAvailable() {
        XCTAssertFalse(GenerationLoadingMessages.messages.isEmpty)
        XCTAssertGreaterThan(GenerationLoadingMessages.messages.count, 5)
    }

    func testLoadingMessagesAreFunnyAndDistinct() {
        let messages = Set(GenerationLoadingMessages.messages)
        XCTAssertEqual(messages.count, GenerationLoadingMessages.messages.count)
        XCTAssertGreaterThan(GenerationLoadingMessages.messages.count, 30)
        XCTAssertTrue(GenerationLoadingMessages.messages.allSatisfy { $0.count >= 8 })
    }

    func testLoadingMessageRotationCyclesByTick() {
        let first = GenerationLoadingMessages.message(forTick: 0)
        let second = GenerationLoadingMessages.message(forTick: 1)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(GenerationLoadingMessages.message(forTick: 0), GenerationLoadingMessages.message(forTick: 48))
        XCTAssertEqual(GenerationLoadingMessages.message(forTick: 1), GenerationLoadingMessages.message(forTick: 49))
        XCTAssertEqual(GenerationLoadingMessages.message(forTick: 2), GenerationLoadingMessages.message(forTick: 50))
        XCTAssertEqual(GenerationLoadingMessages.message(forTick: 3), GenerationLoadingMessages.message(forTick: 55))

        let sample = (0..<12).map { GenerationLoadingMessages.message(forTick: $0) }
        XCTAssertEqual(Set(sample).count, 12)
    }

    func testLoadingMessagePhasesProgressThematically() {
        let boot = GenerationLoadingMessages.phaseTitle(forTick: 2)
        let shape = GenerationLoadingMessages.phaseTitle(forTick: 16)
        let curate = GenerationLoadingMessages.phaseTitle(forTick: 30)
        let polish = GenerationLoadingMessages.phaseTitle(forTick: 48)
        XCTAssertNotEqual(boot, shape)
        XCTAssertNotEqual(shape, curate)
        XCTAssertNotEqual(curate, polish)
        XCTAssertTrue(!GenerationLoadingMessages.phaseTitle(forTick: 16).isEmpty)
        XCTAssertTrue(!GenerationLoadingMessages.phaseTitle(forTick: 30).isEmpty)
        XCTAssertTrue(!GenerationLoadingMessages.phaseTitle(forTick: 48).isEmpty)
    }
}
