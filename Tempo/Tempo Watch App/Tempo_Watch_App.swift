//
//  Tempo_Watch_AppApp.swift
//  Tempo Watch App Watch App
//
//  Created by Charles Wang on 5/29/26.
//

import SwiftUI
import SwiftData
import LifeTrackerCore

@main
struct Tempo_Watch_App_Watch_AppApp: App {
    let sharedContainer: ModelContainer

    init() {
        do {
            sharedContainer = try TempoModelContainer.makeShared()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Seed defaults if the watch happens to launch before the phone ever has.
                    DefaultCategories.seedIfNeeded(in: sharedContainer.mainContext)
                    ConnectivityService.shared.start(container: sharedContainer)
                }
        }
        .modelContainer(sharedContainer)
    }
}
