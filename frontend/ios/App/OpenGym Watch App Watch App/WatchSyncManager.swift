import Foundation
import WatchConnectivity
import Combine

class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncManager()
    
    @Published var routines: [Routine] = []
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation state
    }
    
    // Receive routine data from iOS
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let routinesData = applicationContext["routines"] as? Data {
            if let decoded = try? JSONDecoder().decode([Routine].self, from: routinesData) {
                DispatchQueue.main.async {
                    self.routines = decoded
                }
            }
        }
    }
    
    // Send completed workout data to iOS
    func sendCompletedWorkout(routine: Routine) {
        if let encoded = try? JSONEncoder().encode(routine) {
            let payload: [String: Any] = ["completedWorkout": encoded]
            WCSession.default.transferUserInfo(payload)
        }
    }
}
