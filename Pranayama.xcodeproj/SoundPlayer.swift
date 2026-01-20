import AVFoundation
import AudioToolbox

final class SoundPlayer {
    static let shared = SoundPlayer()
    
    private init() {
        // Configure audio session category to .ambient so it respects silent switch and mixes
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }
    
    func playPhase() {
        // use system sound 1106 (Tink) which is soft and short
        AudioServicesPlaySystemSound(1106)
    }
    
    func playCompletion() {
        // use system sound 1112 (Bell) which is still short but slightly more distinct
        AudioServicesPlaySystemSound(1112)
    }
}

// Replace with custom assets later if desired.
