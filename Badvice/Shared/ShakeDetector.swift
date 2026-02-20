import CoreMotion
import Foundation
import SwiftUI

class ShakeDetector: ObservableObject {
    private let motionManager = CMMotionManager()
    private var lastShakeTime: Date = Date.distantPast
    private let shakeCooldown: TimeInterval = 0.8
    
    @Published var didShake = false
    
    var isEnabled = true
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        stopMonitoring()
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, self.isEnabled, let data = data else { return }
            
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            // Threshold for shake detection (roughly 2.5x gravity)
            if acceleration > 2.5 {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                    self.lastShakeTime = now
                    self.didShake = true
                    
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.didShake = false
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
}

