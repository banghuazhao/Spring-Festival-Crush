//
// Created by Banghua Zhao on 29/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//
  

import SwiftData

class RecordManager {
    static let shared = RecordManager()

    let container: ModelContainer

    private init() {
        
        let schema = Schema([
            ZodiacRecord.self,
            LevelRecord.self,
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        
        do {
            container = try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    func initRecords() {
        
    }
    
    // Add any other data management methods here
}
