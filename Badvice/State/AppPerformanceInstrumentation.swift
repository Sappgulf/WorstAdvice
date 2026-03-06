import Foundation
import OSLog

@MainActor
enum AppPerformanceInstrumentation {
    struct IntervalToken {
        fileprivate let name: StaticString
        fileprivate let signpostState: OSSignpostIntervalState
        fileprivate let startedAt: CFAbsoluteTime
        fileprivate let debugLabel: String
    }

    private static let perfLogger = Logger(subsystem: "com.worstadvice.app", category: "performance")
    private static let signposter = OSSignposter(logger: perfLogger)
    private static var coldStartToken: IntervalToken?
    private static var didCompleteAdviceFirstRender = false

    static func beginColdStartIfNeeded() {
        guard coldStartToken == nil else { return }
        coldStartToken = beginInterval("ColdStartToAdviceFirstRender", debugLabel: "cold_start")
    }

    static func markAdviceTabFirstRenderIfNeeded() {
        guard !didCompleteAdviceFirstRender else { return }
        didCompleteAdviceFirstRender = true
        if let coldStartToken {
            endInterval(coldStartToken)
            self.coldStartToken = nil
        } else {
            signposter.emitEvent("AdviceFirstRender")
            #if DEBUG
                perfLogger.debug("perf event=advice_first_render")
            #endif
        }
    }

    static func beginAdviceGenerationInterval() -> IntervalToken {
        beginInterval("AdviceGenerationRequestToDisplay", debugLabel: "advice_generation")
    }

    static func endAdviceGenerationInterval(_ token: IntervalToken) {
        endInterval(token)
    }

    static func beginLocalModelWarmUpInterval(modelID: String) -> IntervalToken {
        let token = beginInterval("LocalModelWarmUp", debugLabel: "local_model_warmup:\(modelID)")
        #if DEBUG
            perfLogger.debug("perf local_model_warmup_begin id=\(modelID, privacy: .public)")
        #endif
        return token
    }

    static func endLocalModelWarmUpInterval(_ token: IntervalToken, modelID: String) {
        endInterval(token)
        #if DEBUG
            perfLogger.debug("perf local_model_warmup_end id=\(modelID, privacy: .public)")
        #endif
    }

    private static func beginInterval(_ name: StaticString, debugLabel: String) -> IntervalToken {
        let state = signposter.beginInterval(name)
        return IntervalToken(
            name: name,
            signpostState: state,
            startedAt: CFAbsoluteTimeGetCurrent(),
            debugLabel: debugLabel
        )
    }

    private static func endInterval(_ token: IntervalToken) {
        signposter.endInterval(token.name, token.signpostState)
        #if DEBUG
            let elapsedMS = (CFAbsoluteTimeGetCurrent() - token.startedAt) * 1_000
            perfLogger.debug(
                "perf interval=\(token.debugLabel, privacy: .public) elapsed_ms=\(elapsedMS, privacy: .public)"
            )
        #endif
    }
}
