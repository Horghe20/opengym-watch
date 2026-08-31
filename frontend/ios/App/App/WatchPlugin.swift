import Foundation
import Capacitor
import WatchConnectivity

@objc(WatchPlugin)
public class WatchPlugin: CAPPlugin, WCSessionDelegate {
    
    public override func load() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    @objc func sendRoutine(_ call: CAPPluginCall) {
        guard let routine = call.getArray("routines", [String: Any].self) else {
            call.reject("Must provide routines array")
            return
        }
        
        do {
            // Convert back to Data to send over WCSession
            let data = try JSONSerialization.data(withJSONObject: routine, options: [])
            
            // In WatchConnectivity, updateApplicationContext is the best way to send state (like a list of routines)
            try WCSession.default.updateApplicationContext(["routines": data])
            
            call.resolve(["success": true])
        } catch {
            call.reject("Failed to encode routines: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate Stubs
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    // Ascolta i risultati dell'allenamento inviati dall'orologio tramite transferUserInfo
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let completedWorkoutData = userInfo["completedWorkout"] as? Data {
            if let json = try? JSONSerialization.jsonObject(with: completedWorkoutData, options: []) as? [String: Any] {
                // Notifica l'app web Javascript
                self.notifyListeners("onWorkoutCompleted", data: json)
            }
        }
    }
}
