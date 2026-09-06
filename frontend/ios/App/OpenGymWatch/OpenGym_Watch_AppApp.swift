//
//  OpenGym_Watch_AppApp.swift
//  OpenGym Watch App Watch App
//
//  Created by Giorgio Di Cristofalo on 30/08/26.
//

import SwiftUI

@main
struct OpenGym_Watch_App_Watch_AppApp: App {
    init() {
        WorkoutManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
