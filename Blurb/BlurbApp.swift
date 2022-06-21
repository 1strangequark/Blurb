//
//  BlurbApp.swift
//  Blurb
//
//  Created by Jonathan Davies on 6/20/22.
//

import SwiftUI

@main
struct BlurbApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
