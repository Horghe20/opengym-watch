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
        guard activationState == .activated else { return }

        // FIX #4: leggi prima il contesto già disponibile — non serve il tunnel
        let ctx = WCSession.default.receivedApplicationContext
        if !ctx.isEmpty {
            DispatchQueue.main.async { self.handleContext(ctx) }
        } else {
            // FIX #1: requestSync() solo se l'iPhone è realmente raggiungibile (foreground)
            requestSync()
        }
    }

    // Riceve aggiornamenti del contesto dall'iPhone (modalità background-safe)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.handleContext(applicationContext) }
    }

    // FIX #3: gestisce sia i messaggi senza replyHandler...
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.handleContext(message) }
    }

    // FIX #3: ...sia i messaggi CON replyHandler (che è il tipo inviato da requestSync)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { self.handleContext(message) }
        replyHandler([:]) // risponde subito per rilasciare il tunnel
    }

    // MARK: - Data Handling

    func handleContext(_ context: [String: Any]) {
        // FIX #2: supporta sia array diretto (nuovo formato) sia Data wrappata (legacy)
        if let routinesArray = context["routines"] as? [[String: Any]],
           let jsonData = try? JSONSerialization.data(withJSONObject: routinesArray) {
            decode(from: jsonData)
        } else if let routinesData = context["routines"] as? Data {
            decode(from: routinesData)
        } else {
            print("[WatchSyncManager] Nessuna routine nel contesto ricevuto")
        }
    }

    private func decode(from data: Data) {
        do {
            let decoded = try JSONDecoder().decode([Routine].self, from: data)
            DispatchQueue.main.async {
                self.routines = decoded
                print("[WatchSyncManager] ✅ \(decoded.count) routine ricevute")
            }
        } catch {
            print("[WatchSyncManager] ❌ Decodifica fallita: \(error)")
        }
    }

    // MARK: - Sync Request

    func requestSync() {
        // FIX #1: invia sendMessage SOLO se iPhone è in foreground (isReachable)
        // Se non è raggiungibile, aspetta — arriverà tramite applicationContext
        guard WCSession.default.isReachable else {
            print("[WatchSyncManager] iPhone non raggiungibile, in attesa del contesto...")
            return
        }
        WCSession.default.sendMessage(["request": "sync"], replyHandler: { [weak self] response in
            DispatchQueue.main.async { self?.handleContext(response) }
        }, errorHandler: { error in
            print("[WatchSyncManager] sendMessage error: \(error.localizedDescription)")
            // Fallback silenzioso — non destabilizzare la sessione WCSession
        })
    }

    // MARK: - Send Completed Workout

    func sendCompletedWorkout(routine: Routine) {
        if let encoded = try? JSONEncoder().encode(routine) {
            let payload: [String: Any] = ["completedWorkout": encoded]
            WCSession.default.transferUserInfo(payload)
        }
    }
}
