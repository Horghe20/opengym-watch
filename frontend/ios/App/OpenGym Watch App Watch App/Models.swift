import Foundation

// MARK: - App Models
struct Routine: Identifiable, Codable {
    let id: String
    let title: String
    let notes: String?
    var exercises: [Exercise]
}

struct Exercise: Identifiable, Codable {
    let id: String
    let name: String
    var sets: [WorkoutSet]
}

struct WorkoutSet: Identifiable, Codable {
    let id: String
    var reps: Int
    var weight: Double
    var isCompleted: Bool
    
    // Fallback initializer
    init(id: String = UUID().uuidString, reps: Int, weight: Double, isCompleted: Bool = false) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
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
