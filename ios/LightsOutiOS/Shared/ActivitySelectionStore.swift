import Foundation
import FamilyControls
import ManagedSettings

/// Persistence for the user's `FamilyActivitySelection` — the opaque set of apps,
/// categories, and web domains they chose to restrict.
///
/// The tokens inside `FamilyActivitySelection` are opaque, device-local, and
/// privacy-preserving: we can't inspect bundle IDs. We only persist the whole
/// selection so later runs can apply the same shields and the picker can round-trip
/// the user's previous choice.
public enum ActivitySelectionStore {

    /// Load the persisted selection. Returns an empty selection if nothing stored.
    public static func load() -> FamilyActivitySelection {
        guard let data = AppGroup.userDefaults.data(forKey: AppGroupKey.activitySelection) else {
            return FamilyActivitySelection()
        }
        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            NSLog("[LightsOut] Failed to decode activity selection: \(error); returning empty")
            return FamilyActivitySelection()
        }
    }

    /// Persist the selection so the monitor extension can reconstruct it later.
    public static func save(_ selection: FamilyActivitySelection) {
        do {
            let data = try JSONEncoder().encode(selection)
            AppGroup.userDefaults.set(data, forKey: AppGroupKey.activitySelection)
        } catch {
            NSLog("[LightsOut] Failed to encode activity selection: \(error)")
        }
    }

    /// True if the user has selected at least one app, category, or web domain.
    public static var isEmpty: Bool {
        let s = load()
        return s.applicationTokens.isEmpty
            && s.categoryTokens.isEmpty
            && s.webDomainTokens.isEmpty
    }
}
