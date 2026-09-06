import Foundation
import Capacitor
import WatchConnectivity

@objc(WatchPlugin)
public class WatchPlugin: CAPPlugin, WCSessionDelegate {

    // FIX #2: mantieni l'array nativo invece di Data wrappata
    // FIX #2: mantieni l'array nativo ma salvalo in UserDefaults come JSON Data (per supportare i null provenienti da JS)
    private var pendingRoutinesArray: [[String: Any]]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchSyncRoutines"),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }
            return array
        }
        set {
            if let val = newValue, let data = try? JSONSerialization.data(withJSONObject: val) {
                UserDefaults.standard.set(data, forKey: "watchSyncRoutines")
            }
        }
    }

    public override func load() {
        // FIX #5: proteggi da reload multipli — attiva solo se non già attivo
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState == .notActivated {
            session.activate()
        }
    }

    @objc func sendRoutine(_ call: CAPPluginCall) {
        guard let routinesArray = call.getArray("routines", [String: Any].self) else {
            call.reject("Must provide routines array")
            return
        }

        // FIX #2: salva come array nativo, non come Data wrappata
        self.pendingRoutinesArray = routinesArray

        do {
            if WCSession.default.activationState == .activated {
                // FIX #2: invia array diretto nel contesto — evita overhead Data e rispetta i limiti 65KB
                try WCSession.default.updateApplicationContext(["routines": routinesArray])
                print("[WatchPlugin] ✅ applicationContext aggiornato con \(routinesArray.count) routine")
            } else {
                print("[WatchPlugin] WCSession non ancora attiva — routine in attesa")
            }
            call.resolve(["success": true])
        } catch {
            call.reject("Failed to update application context: \(error.localizedDescription)")
        }
    }

    @objc func saveWorkoutToHealthKit(_ call: CAPPluginCall) {
        guard call.getDouble("start") != nil,
              call.getDouble("end") != nil else {
            call.reject("Must provide start and end timestamps")
            return
        }
        call.resolve(["success": true])
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let err = error {
            print("[WatchPlugin] Attivazione WCSession fallita: \(err.localizedDescription)")
            return
        }
        // FIX #2: usa array diretto invece di Data quando si invia il contesto pendente
        if activationState == .activated, let routinesArray = pendingRoutinesArray {
            try? WCSession.default.updateApplicationContext(["routines": routinesArray])
            print("[WatchPlugin] ✅ Contesto pendente inviato dopo attivazione")
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // FIX #2: risponde al Watch con array diretto (non Data wrappata)
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                        replyHandler: @escaping ([String: Any]) -> Void) {
        if message["request"] as? String == "sync", let routinesArray = pendingRoutinesArray {
            replyHandler(["routines": routinesArray])
        } else {
            replyHandler([:])
        }
    }

    // Ascolta i risultati dell'allenamento inviati dall'orologio tramite transferUserInfo
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let completedWorkoutData = userInfo["completedWorkout"] as? Data,
           let json = try? JSONSerialization.jsonObject(with: completedWorkoutData) as? [String: Any] {
            self.notifyListeners("onWorkoutCompleted", data: json)
        }
    }
}
