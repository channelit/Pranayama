import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

#if canImport(ActivityKit)
import ActivityKit
#endif

// Inline fallback sound helper to ensure availability within this file
final class InlineSoundPlayer {
    static let shared = InlineSoundPlayer()
    private init() {
        // Configure audio session to ambient so it mixes and stays unobtrusive
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }
    func playPhase() { AudioServicesPlaySystemSound(1106) }
    func playCompletion() { AudioServicesPlaySystemSound(1112) }
}

enum BreathingPhase: String {
    case inhale = "Inhale"
    case hold = "Hold"
    case exhale = "Exhale"
}

struct BreathingLevel: Identifiable, Equatable {
    let id: Int
    let inhale: Int
    let hold: Int
    let exhale: Int
    let title: String
}

private let levels: [BreathingLevel] = [
    .init(id: 0, inhale: 2, hold: 8, exhale: 4, title: "Level 0 (2-8-4)"),
    .init(id: 1, inhale: 4, hold: 16, exhale: 8, title: "Level 1 (4-16-8)"),
    .init(id: 2, inhale: 5, hold: 20, exhale: 10, title: "Level 2 (5-20-10)"),
    .init(id: 3, inhale: 8, hold: 32, exhale: 16, title: "Level 3 (8-32-16)")
]

struct BreathingTimerView: View {
    @AppStorage("breathLevel") private var breathLevel: Int = 1
    @AppStorage("targetSets") private var targetSets: Int = 4

    @State private var phase: BreathingPhase = .inhale
    @State private var remaining: Int = 0
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var completedCycles: Int = 0
    @State private var isCompleted: Bool = false

    private var targetCycles: Int { targetSets * 2 }
    private var completedSets: Int { completedCycles / 2 }

    private var livePhase: LiveActivityPhase {
        switch phase {
        case .inhale: return .inhale
        case .hold: return .hold
        case .exhale: return .exhale
        }
    }

    private let phaseImpact = UIImpactFeedbackGenerator(style: .light)
    private let completionNotifier = UINotificationFeedbackGenerator()
    private let sound = InlineSoundPlayer.shared

    private var currentLevel: BreathingLevel {
        levels.first(where: { $0.id == breathLevel }) ?? levels[0]
    }

    private var phaseDuration: Int {
        switch phase {
        case .inhale: return currentLevel.inhale
        case .hold: return currentLevel.hold
        case .exhale: return currentLevel.exhale
        }
    }

    private func nextPhase(after p: BreathingPhase) -> BreathingPhase {
        switch p {
        case .inhale: return .hold
        case .hold: return .exhale
        case .exhale: return .inhale
        }
    }

    private func phaseChangedHaptic() {
        phaseImpact.impactOccurred()
        sound.playPhase()
    }

    private func totalRemainingSessionSeconds() -> Int {
        // Remaining in current phase + remaining cycles
        let level = currentLevel
        var total = remaining
        switch phase {
        case .inhale:
            total += 0
        case .hold:
            total += 0
        case .exhale:
            total += 0
        }
        // Add the rest of the phases for the current cycle
        switch phase {
        case .inhale:
            total += level.hold + level.exhale
        case .hold:
            total += level.exhale
        case .exhale:
            total += 0
        }
        // Add full cycles remaining after current one
        let cyclesLeft = max(targetCycles, 1) - completedCycles - (phase == .exhale && remaining == 0 ? 1 : 0)
        if cyclesLeft > 0 {
            total += cyclesLeft * (level.inhale + level.hold + level.exhale)
        }
        return max(total, 0)
    }

    private func updateLiveActivity() {
        let progress = BreathingProgress(
            currentCycle: completedCycles,
            targetCycles: max(targetCycles, 1),
            phase: livePhase,
            remaining: max(remaining, 0)
        )
        let remainingTotal = totalRemainingSessionSeconds()
        LiveActivityManager.shared.update(progress: progress, remainingTotalSeconds: remainingTotal)
    }

    private func start() {
        if remaining == 0 { remaining = phaseDuration }
        isRunning = true
        #if canImport(ActivityKit)
        let initialProgress = BreathingProgress(
            currentCycle: completedCycles,
            targetCycles: max(targetCycles, 1),
            phase: livePhase,
            remaining: max(remaining == 0 ? phaseDuration : remaining, 0)
        )
        let total = totalRemainingSessionSeconds()
        LiveActivityManager.shared.start(progress: initialProgress, durationSeconds: max(total, 1))
        #endif
        scheduleTimer()
    }

    private func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        #if canImport(ActivityKit)
        LiveActivityManager.shared.end(success: false)
        #endif
    }

    private func reset() {
        pause()
        phase = .inhale
        remaining = 0
        completedCycles = 0
        isCompleted = false
        #if canImport(ActivityKit)
        LiveActivityManager.shared.end(success: false)
        #endif
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
        timer?.tolerance = 0
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard isRunning else { return }
        if remaining > 0 {
            // decrement without long animations to avoid visual lag
            withAnimation(.linear(duration: 0.2)) {
                remaining -= 1
            }
            updateLiveActivity()
            return
        }
        // remaining == 0: immediately advance phase within the same tick
        if phase == .exhale {
            completedCycles += 1
            phaseChangedHaptic()
            if completedCycles >= targetCycles {
                isCompleted = true
                completionNotifier.notificationOccurred(.success)
                sound.playCompletion()
                #if canImport(ActivityKit)
                LiveActivityManager.shared.end(success: true)
                #endif
                pause()
                return
            }
            phase = .inhale
            remaining = phaseDuration
            updateLiveActivity()
        } else {
            phase = nextPhase(after: phase)
            phaseChangedHaptic()
            remaining = phaseDuration
            updateLiveActivity()
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .inhale: return .green
        case .hold: return .yellow
        case .exhale: return .blue
        }
    }

    private var phaseInstruction: String {
        switch phase {
        case .inhale: return "Breathe in"
        case .hold: return "Hold"
        case .exhale: return "Breathe out"
        }
    }

    private var currentNostrilIsLeft: Bool {
        completedCycles % 2 == 0
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Set: \(completedSets + 1) / \(max(targetSets, 1))")
                    .font(.headline)
                    .padding(.top)
                HStack(spacing: 6) {
                    Image(systemName: currentNostrilIsLeft ? "arrow.left.circle" : "arrow.right.circle")
                        .font(.title2)
                        .foregroundColor(currentNostrilIsLeft ? .green : .blue)
                        .accessibilityLabel(currentNostrilIsLeft ? "Left nostril" : "Right nostril")
                    Text(currentNostrilIsLeft ? "Left nostril" : "Right nostril")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(phaseColor.opacity(0.2))
                    .frame(width: 260, height: 260)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: remaining == 0 ? 0 : CGFloat(remaining) / CGFloat(max(phaseDuration, 1)))
                            .stroke(phaseColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    )
                VStack(spacing: 8) {
                    Text(phase.rawValue)
                        .font(.largeTitle).bold()
                    Text(phaseInstruction)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("\(remaining)s")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            Spacer()
            HStack(spacing: 16) {
                if isCompleted {
                    Button("Restart") {
                        reset()
                        start()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(isRunning ? "Pause" : "Start") {
                        isRunning ? pause() : start()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Reset", action: reset)
                    .buttonStyle(.bordered)
            }
            .padding(.bottom)
        }
        .onChange(of: breathLevel) { _, _ in
            // when level changes, reset to start of set
            reset()
            remaining = phaseDuration
        }
        .onDisappear { pause() }
        .onAppear {
            if remaining == 0 { remaining = phaseDuration }
            completedCycles = 0; isCompleted = false
            phaseImpact.prepare()
            completionNotifier.prepare()
            _ = sound
        }
        .navigationTitle(isCompleted ? "Completed" : "Breathing")
    }
}

#Preview {
    BreathingTimerView()
}

