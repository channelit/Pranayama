import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

enum LiveActivityPhase: String, Codable {
    case inhale, hold, exhale
}

struct BreathingProgress: Codable, Hashable {
    let currentCycle: Int
    let targetCycles: Int
    let phase: LiveActivityPhase
    let remaining: Int
}

#if canImport(ActivityKit)
struct BreathingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: BreathingProgress
        var startedAt: Date
        var expectedEnd: Date
    }
    
    // Static attributes
    var version: String = "1.1"
}

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var activity: Activity<BreathingAttributes>? = nil

    func start(progress: BreathingProgress, durationSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let content = BreathingAttributes.ContentState(
            progress: progress,
            startedAt: now,
            expectedEnd: now.addingTimeInterval(TimeInterval(durationSeconds))
        )
        do {
            activity = try Activity<BreathingAttributes>.request(
                attributes: BreathingAttributes(),
                content: ActivityContent(state: content, staleDate: nil),
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Live Activity request failed: \(error)")
            #endif
        }
    }

    func update(progress: BreathingProgress, remainingTotalSeconds: Int) {
        guard let activity else { return }
        let now = Date()
        let update = BreathingAttributes.ContentState(
            progress: progress,
            startedAt: activity.content.state.startedAt,
            expectedEnd: now.addingTimeInterval(TimeInterval(remainingTotalSeconds))
        )
        Task { await activity.update(ActivityContent(state: update, staleDate: nil)) }
    }

    func end(success: Bool) {
        guard let activity else { return }
        let finalState = activity.content.state
        Task {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
    }
}
#else
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}
    func start(progress: BreathingProgress, durationSeconds: Int) {}
    func update(progress: BreathingProgress, remainingTotalSeconds: Int) {}
    func end(success: Bool) {}
}
#endif





