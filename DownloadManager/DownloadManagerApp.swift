//
//  DownloadManagerApp.swift
//  DownloadManager
//
//  Created by ace wei on 2026/5/27.
//

import SwiftUI
import CoreData

@main
struct DownloadManagerApp: App {
    let persistenceController = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
