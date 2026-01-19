import SwiftUI
import UIKit

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
    .init(id: 1, inhale: 4, hold: 16, exhale: 8, title: "Level 1 (4-16-8)"),
    .init(id: 2, inhale: 5, hold: 20, exhale: 10, title: "Level 2 (5-20-10)"),
    .init(id: 3, inhale: 8, hold: 32, exhale: 16, title: "Level 3 (8-32-16)")
]

struct BreathingTimerView: View {
    @AppStorage("breathLevel") private var breathLevel: Int = 1
    @AppStorage("targetCycles") private var targetCycles: Int = 4

    @State private var phase: BreathingPhase = .inhale
    @State private var remaining: Int = 0
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var completedCycles: Int = 0
    @State private var isCompleted: Bool = false

    private let phaseImpact = UIImpactFeedbackGenerator(style: .light)
    private let completionNotifier = UINotificationFeedbackGenerator()

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
    }

    private func start() {
        if remaining == 0 { remaining = phaseDuration }
        isRunning = true
        scheduleTimer()
    }

    private func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func reset() {
        pause()
        phase = .inhale
        remaining = 0
        completedCycles = 0
        isCompleted = false
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
            return
        }
        // remaining == 0: immediately advance phase within the same tick
        if phase == .exhale {
            completedCycles += 1
            phaseChangedHaptic()
            if completedCycles >= max(targetCycles, 1) {
                isCompleted = true
                completionNotifier.notificationOccurred(.success)
                pause()
                return
            }
            phase = .inhale
            remaining = phaseDuration
        } else {
            phase = nextPhase(after: phase)
            phaseChangedHaptic()
            remaining = phaseDuration
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

    var body: some View {
        VStack(spacing: 24) {
            Text("Cycle: \(completedCycles) / \(max(targetCycles, 1))")
                .font(.headline)
                .padding(.top)
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
            // when level changes, reset to start of cycle
            reset()
            remaining = phaseDuration
        }
        .onDisappear { pause() }
        .onAppear {
            if remaining == 0 { remaining = phaseDuration }
            completedCycles = 0; isCompleted = false
            phaseImpact.prepare()
            completionNotifier.prepare()
        }
        .navigationTitle(isCompleted ? "Completed" : "Breathing")
    }
}

#Preview {
    BreathingTimerView()
}
