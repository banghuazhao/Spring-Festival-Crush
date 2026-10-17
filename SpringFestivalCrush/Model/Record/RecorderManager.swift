//
// Created by Banghua Zhao on 29/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//


import Foundation
import SwiftData

class RecordManager {
    static let shared = RecordManager()

    let container: ModelContainer

    private init() {
        container = Self.makeContainer()
    }

    static let schema = Schema([
        ZodiacRecord.self,
        LevelRecord.self,
    ])

    /// Opens the saved progress. If the store cannot be opened (a full disk, a failed
    /// migration), the game still launches on an in-memory store instead of crashing on every
    /// launch. The file on disk is left untouched, so a later launch can open it again.
    static func makeContainer(url: URL? = nil) -> ModelContainer {
        let saved = url.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: saved)
        } catch {
            print("Failed to open saved progress, playing without saving this session: \(error)")
        }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        } catch {
            fatalError("Failed to initialize an in-memory ModelContainer: \(error)")
        }
    }
}
