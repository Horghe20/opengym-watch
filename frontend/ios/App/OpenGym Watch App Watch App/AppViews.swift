import SwiftUI
import WatchKit

// MARK: - Home View
struct HomeView: View {
    @StateObject private var workoutManager = WorkoutManager.shared
    
    // In a real app, this would be fetched from iOS via WatchSyncManager
    let routines = Routine.dummyRoutines
    
    var body: some View {
        NavigationView {
            List(routines) { routine in
                Button(action: {
                    workoutManager.startWorkout(routine: routine)
                }) {
                    VStack(alignment: .leading) {
                        Text(routine.title)
                            .font(.headline)
                        if let notes = routine.notes {
                            Text(notes)
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Routines")
        }
        .fullScreenCover(isPresented: $workoutManager.isRunning) {
            WorkoutTabView()
                .environmentObject(workoutManager)
        }
    }
}

// MARK: - Workout Tab View
struct WorkoutTabView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var selection = 1
    
    var body: some View {
        TabView(selection: $selection) {
            ControlsView()
                .tag(0)
            
            ActiveExerciseView()
                .tag(1)
            
            NowPlayingView()
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
    }
}

// MARK: - Controls View
struct ControlsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showingEndAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text(formatTime(workoutManager.elapsedTime))
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(.yellow)
            
            HStack(spacing: 16) {
                VStack {
                    Text(String(format: "%.0f", workoutManager.heartRate))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text(String(format: "%.0f", workoutManager.activeEnergy))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("KCAL")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Button(action: {
                showingEndAlert = true
            }) {
                Text("End Workout")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .tint(.red)
            .alert(isPresented: $showingEndAlert) {
                Alert(
                    title: Text("Termina Allenamento"),
                    message: Text("Sei sicuro di voler terminare l'allenamento?"),
                    primaryButton: .destructive(Text("Termina")) {
                        workoutManager.endWorkout()
                    },
                    secondaryButton: .cancel(Text("Annulla"))
                )
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Active Exercise View
struct ActiveExerciseView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    @State private var currentWeight: Double = 0
    @State private var currentReps: Double = 0
    @State private var showRestTimer = false
    
    var body: some View {
        if let routine = workoutManager.activeRoutine {
            let exercise = routine.exercises[workoutManager.currentExerciseIndex]
            let set = exercise.sets[workoutManager.currentSetIndex]
            
            VStack {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                Text("Set \(workoutManager.currentSetIndex + 1) of \(exercise.sets.count)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    CrownPickerBox(label: "KG", value: $currentWeight, step: 1.25, isWeight: true)
                    CrownPickerBox(label: "REPS", value: $currentReps, step: 1.0, isWeight: false)
                }
                .padding(.vertical, 4)
                
                Button(action: {
                    workoutManager.completeCurrentSet(weight: currentWeight, reps: Int(currentReps))
                    showRestTimer = true
                }) {
                    Text("DONE")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.green)
                .cornerRadius(12)
            }
            .onAppear {
                currentWeight = set.weight
                currentReps = Double(set.reps)
            }
            .onChange(of: workoutManager.currentSetIndex) { _ in
                let newSet = routine.exercises[workoutManager.currentExerciseIndex].sets[workoutManager.currentSetIndex]
                currentWeight = newSet.weight
                currentReps = Double(newSet.reps)
            }
            .sheet(isPresented: $showRestTimer) {
                RestTimerView(isPresented: $showRestTimer)
            }
        } else {
            Text("No Active Workout")
        }
    }
}

// MARK: - Rest Timer View
struct RestTimerView: View {
    @Binding var isPresented: Bool
    
    @State private var timeRemaining = 60
    @State private var totalTime = 60
    
    var body: some View {
        VStack {
            Text("REST")
                .font(.headline)
                .foregroundColor(.gray)
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.3)
                    .foregroundColor(.green)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(timeRemaining) / CGFloat(totalTime))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.green)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: timeRemaining)
                
                Text("\(timeRemaining)")
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
            }
            .padding()
            
            Button("Skip") {
                finishRest()
            }
            .font(.footnote)
            .foregroundColor(.gray)
        }
        .onAppear {
            startTimer()
        }
    }
    
    func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                finishRest()
            }
        }
    }
    
    func finishRest() {
        WKInterfaceDevice.current().play(.notification)
        isPresented = false
    }
}
