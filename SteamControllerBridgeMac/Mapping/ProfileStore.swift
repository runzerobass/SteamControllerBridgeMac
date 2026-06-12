import Foundation
import os.log

/// Loads and bootstraps the user's mapping profile:
/// ~/Library/Application Support/SteamControllerBridgeMac/profile.json
enum ProfileStore {
    static let url = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SteamControllerBridgeMac/profile.json")

    private static let log = Logger(subsystem: "com.arvindrao.SteamControllerBridgeMac", category: "profile")

    /// Loads the profile, writing the default file first if none exists.
    /// A malformed file falls back to defaults (and is left untouched for
    /// the user to fix).
    static func load() -> Profile {
        writeDefaultIfMissing()
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Profile.self, from: data)
        } catch {
            log.error("profile.json unreadable, using defaults: \(error.localizedDescription, privacy: .public)")
            return .defaultProfile
        }
    }

    // MARK: - Named user profiles

    static let userProfilesDir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("SteamControllerBridgeMac/profiles", isDirectory: true)

    static func listUserProfiles() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(at: userProfilesDir,
                                                                  includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent } ?? []
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func loadUserProfile(named name: String) -> Profile? {
        guard let data = try? Data(contentsOf: userProfileURL(name)) else { return nil }
        return try? JSONDecoder().decode(Profile.self, from: data)
    }

    static func saveUserProfile(_ profile: Profile, named name: String) throws {
        try FileManager.default.createDirectory(at: userProfilesDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: userProfileURL(name), options: .atomic)
    }

    static func deleteUserProfile(named name: String) {
        try? FileManager.default.removeItem(at: userProfileURL(name))
    }

    private static func userProfileURL(_ name: String) -> URL {
        let safe = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return userProfilesDir.appendingPathComponent(safe + ".json")
    }

    static func save(_ profile: Profile) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: url, options: .atomic)
    }

    static func writeDefaultIfMissing() {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Profile.defaultProfile) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
