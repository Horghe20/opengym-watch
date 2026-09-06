import Foundation
import HealthKit
import Combine

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    lazy var healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // Published values for UI
    @Published var activeRoutine: Routine?
    @Published var currentExerciseIndex: Int = 0
    @Published var currentSetIndex: Int = 0
    
    @Published var isRunning = false
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    
    private var timer: Timer?
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[WorkoutManager] HealthKit non disponibile su questo device")
            return
        }

        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if let error = error {
                print("[WorkoutManager] Autorizzazione HealthKit fallita: \(error.localizedDescription)")
            } else {
                print("[WorkoutManager] Autorizzazione HealthKit: \(success ? "concessa" : "negata dall'utente")")
            }
        }
    }
    
    func startWorkout(routine: Routine) {
        self.activeRoutine = routine
        self.currentExerciseIndex = 0
        self.currentSetIndex = 0
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            print("[WorkoutManager] Impossibile creare la sessione HealthKit: \(error.localizedDescription)")
            return
        }

        session?.delegate = self
        builder?.delegate = self

        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { (success, error) in
            if let error = error {
                print("[WorkoutManager] beginCollection fallita: \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async {
            self.isRunning = true
        }
        startTimer()
    }
    
    func pauseWorkout() {
        session?.pause()
        stopTimer()
        DispatchQueue.main.async { self.isRunning = false }
    }
    
    func resumeWorkout() {
        session?.resume()
        startTimer()
        DispatchQueue.main.async { self.isRunning = true }
    }
    
    func endWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { (success, error) in
            if let error = error {
                print("[WorkoutManager] endCollection fallita: \(error.localizedDescription)")
                return
            }
            self.builder?.finishWorkout { (workout, error) in
                if let error = error {
                    print("[WorkoutManager] finishWorkout fallita: \(error.localizedDescription)")
                } else if workout == nil {
                    print("[WorkoutManager] finishWorkout non ha prodotto un workout da salvare")
                }
            }
        }
        stopTimer()
        DispatchQueue.main.async {
            self.activeRoutine = nil
            self.isRunning = false
            self.elapsedTime = 0
            self.heartRate = 0
            self.activeEnergy = 0
        }
    }
    
    // MARK: - App Logic
    func completeCurrentSet(weight: Double, reps: Int) {
        guard var routine = activeRoutine else { return }
        
        // Update the set
        routine.exercises[currentExerciseIndex].sets[currentSetIndex].weight = weight
        routine.exercises[currentExerciseIndex].sets[currentSetIndex].reps = reps
        routine.exercises[currentExerciseIndex].sets[currentSetIndex].isCompleted = true
        self.activeRoutine = routine // trigger UI update
        
        // Advance to next set or exercise
        let currentExercise = routine.exercises[currentExerciseIndex]
        if currentSetIndex < currentExercise.sets.count - 1 {
            currentSetIndex += 1
        } else {
            // Next exercise
            if currentExerciseIndex < routine.exercises.count - 1 {
                currentExerciseIndex += 1
                currentSetIndex = 0
            } else {
                // Workout completed!
                // We could automatically end it or let the user review it
            }
        }
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.elapsedTime += 1
        }
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - HK Delegates
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[WorkoutManager] Sessione HealthKit fallita: \(error.localizedDescription)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    self.activeEnergy = statistics?.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                default:
                    break
                }
            }
        }
    }
}
import Foundation

// MARK: - App Models
struct Routine: Identifiable, Codable {
    let id: String
    let title: String
    let notes: String?
    var exercises: [Exercise]
    
    // Mapping from JS
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "name"
        case notes = "note"
        case exercises = "ex"
    }
}

struct Exercise: Identifiable, Codable {
    let id: String
    let name: String
    var sets: [WorkoutSet]
    
    // JS sends mode or we can infer it
    var isTimeBased: Bool?
    var restTimer: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name = "name"
        case sets = "sets"
        case isTimeBased = "isTimeBased"
        case restTimer = "restTimer"
    }
}

struct WorkoutSet: Identifiable, Codable {
    let id: String
    var reps: Int?
    var weight: Double?
    var seconds: Int?
    var isCompleted: Bool
    
    init(id: String = UUID().uuidString, reps: Int? = nil, weight: Double? = nil, seconds: Int? = nil, isCompleted: Bool = false) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.seconds = seconds
        self.isCompleted = isCompleted
    }
    
    enum CodingKeys: String, CodingKey {
        case id, reps, weight, seconds, isCompleted
    }
}

// MARK: - Dummy Data for Testing
extension Routine {
    static let dummyRoutines = [
        Routine(id: "1", title: "Push Day", notes: "Chest, Shoulders, Triceps", exercises: [
            Exercise(id: "e1", name: "Bench Press", sets: [
                WorkoutSet(reps: 8, weight: 80.0),
                WorkoutSet(reps: 8, weight: 80.0),
                WorkoutSet(reps: 8, weight: 82.5)
            ]),
            Exercise(id: "e2", name: "Overhead Press", sets: [
                WorkoutSet(reps: 10, weight: 50.0),
                WorkoutSet(reps: 10, weight: 50.0)
            ])
        ]),
        Routine(id: "2", title: "Pull Day", notes: "Back and Biceps", exercises: [
            Exercise(id: "e3", name: "Pull Ups", sets: [
                WorkoutSet(reps: 10, weight: 0),
                WorkoutSet(reps: 10, weight: 0)
            ])
        ])
    ]
}
