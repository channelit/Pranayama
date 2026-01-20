import SwiftUI

struct ContentView: View {
    @AppStorage("breathLevel") private var breathLevel: Int = 1
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
            // Dismiss splash after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("breathLevel") private var breathLevel: Int = 1
    @AppStorage("targetCycles") private var targetCycles: Int = 4

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

                Section("Target Cycles") {
                    Stepper(value: $targetCycles, in: 1...100) {
                        Text("\(targetCycles) cycles")
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
