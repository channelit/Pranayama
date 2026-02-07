import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("breathLevel") private var breathLevel: Int = 1
    @AppStorage("keepAwake") private var keepAwake: Bool = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash: Bool = true
    @State private var showSettings: Bool = false

    var body: some View {
        ZStack {
            NavigationStack {
                BreathingTimerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("Settings")
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView()
                    }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Migrate old targetCycles key to targetSets if needed
            let defaults = UserDefaults.standard
            if defaults.object(forKey: "targetCycles") != nil && defaults.object(forKey: "targetSets") == nil {
                let oldValue = defaults.integer(forKey: "targetCycles")
                defaults.set(oldValue, forKey: "targetSets")
                defaults.removeObject(forKey: "targetCycles")
            }

            // Dismiss splash after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                UIApplication.shared.isIdleTimerDisabled = keepAwake
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onChange(of: keepAwake) { _, newValue in
            if scenePhase == .active {
                UIApplication.shared.isIdleTimerDisabled = newValue
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("breathLevel") private var breathLevel: Int = 1
    @AppStorage("targetSets") private var targetSets: Int = 4
    @AppStorage("keepAwake") private var keepAwake: Bool = true

    var body: some View {
        NavigationStack {
            List {
                Section("Breathing Level") {
                    Picker("Level", selection: $breathLevel) {
                        Text("Level 0 (2-8-4)").tag(0)
                        Text("Level 1 (4-16-8)").tag(1)
                        Text("Level 2 (5-20-10)").tag(2)
                        Text("Level 3 (8-32-16)").tag(3)
                    }
                    .pickerStyle(.inline)
                }

                Section("Target Sets") {
                    Stepper(value: $targetSets, in: 1...100) {
                        Text("\(targetSets) sets")
                    }
                }

                Section("Screen") {
                    Toggle(isOn: $keepAwake) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keep screen awake during session")
                            Text("Prevents auto-lock while the app is active.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    Text("This is a simple pranayama timer guiding inhale, hold, and exhale.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lungs.fill")
                    .font(.system(size: 84))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                Text("Pranayama")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Breathe • Hold • Exhale")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}

#Preview {
    ContentView()
}
