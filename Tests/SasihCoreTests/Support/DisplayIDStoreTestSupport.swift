import Foundation
@testable import SasihCore

/// Kept in a file that does NOT import `Testing`, working around a missing
/// `_Testing_Foundation` cross-import overlay module in this machine's
/// Command Line Tools install (no full Xcode.app) — importing Foundation and
/// Testing together in the same file fails to resolve that overlay here.
/// The actual `@Test` cases live in DisplayIDStoreTests.swift and just call
/// into these scenario functions, keeping Testing+Foundation in separate files.
enum DisplayIDStoreScenario {
    private static func withStore<T>(_ body: (DisplayIDStore, UserDefaults) -> T) -> T {
        let suiteName = "SasihCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sasih_test_\(UUID().uuidString).txt")
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        let store = DisplayIDStore(defaults: defaults, fileURL: fileURL)
        return body(store, defaults)
    }

    static func roundTripSaveLoad() -> Bool {
        withStore { store, _ in
            store.save(42)
            return store.load() == 42
        }
    }

    static func loadReturnsNilWhenNothingSaved() -> Bool {
        withStore { store, _ in store.load() == nil }
    }

    static func fallsBackToFileWhenDefaultsMissing() -> Bool {
        withStore { store, defaults in
            store.save(7)
            defaults.removeObject(forKey: "BackupInternalDisplayID")
            return store.load() == 7
        }
    }

    static func usesDefaultsWhenFileIsCorruptOrMissing() -> Bool {
        var storedFileURL: URL!
        let suiteName = "SasihCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        storedFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sasih_test_\(UUID().uuidString).txt")
        let store = DisplayIDStore(defaults: defaults, fileURL: storedFileURL)
        store.save(9)
        try? FileManager.default.removeItem(at: storedFileURL)
        return store.load() == 9
    }

    static func offStateDefaultsToFalse() -> Bool {
        withStore { store, _ in store.loadOffState() == false }
    }

    static func offStateRoundTrip() -> Bool {
        withStore { store, _ in
            store.saveOffState(true)
            guard store.loadOffState() == true else { return false }
            store.saveOffState(false)
            return store.loadOffState() == false
        }
    }
}
