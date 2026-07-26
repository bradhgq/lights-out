import ManagedSettings
import ManagedSettingsUI
import UIKit
import LightsOutCore

/// Custom UI for the shield shown when a user taps a blocked app or web page.
///
/// The system creates a fresh instance of this class per shield presentation, reads
/// the returned `ShieldConfiguration`, and renders it. We don't own layout — the
/// shield is rendered by the system — we just specify colors, title, subtitle, icon,
/// and button labels.
///
/// We vary the shield by phase, derived from the `ManagedSettingsStore` name passed
/// in. Since the name encodes the phase, we don't need to read from the App Group —
/// though we could (via `PhaseState.current`) if we wanted the shield copy to reflect
/// transient state like "12 minutes until morning".
final class LightsOutShieldConfiguration: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let phase = phase(from: currentStoreName())
        return shieldConfiguration(for: phase, appName: application.localizedDisplayName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        let phase = phase(from: currentStoreName())
        return shieldConfiguration(for: phase, appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let phase = phase(from: currentStoreName())
        return shieldConfiguration(for: phase, appName: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        let phase = phase(from: currentStoreName())
        return shieldConfiguration(for: phase, appName: webDomain.domain)
    }

    // MARK: - Helpers

    /// Build a per-phase shield config. The primary button ("Request override") is
    /// handled by `LightsOutShieldAction`, which opens the main app to drive the
    /// friction flow.
    private func shieldConfiguration(for phase: Phase, appName: String?) -> ShieldConfiguration {
        let title: String
        let subtitle: String
        let bg: UIColor
        let tint: UIColor
        let primary: String?

        switch phase {
        case .amber:
            title = "Wind-down is approaching"
            subtitle = appName.map { "\($0) will rest soon. Consider closing it." }
                ?? "Consider closing this."
            bg = UIColor(red: 0.2, green: 0.15, blue: 0.08, alpha: 1.0)
            tint = .systemOrange
            primary = "Continue anyway"
        case .windDown:
            title = "Apps are resting"
            subtitle = appName.map { "\($0) is resting for the night." }
                ?? "This app is resting for the night."
            bg = UIColor(red: 0.15, green: 0.08, blue: 0.05, alpha: 1.0)
            tint = .systemOrange
            primary = "Request override"
        case .lightsOut:
            title = "Lights Out"
            subtitle = appName.map { "\($0) is closed until morning." }
                ?? "Closed until morning."
            bg = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
            tint = .systemIndigo
            primary = "Emergency override"
        case .idle:
            // Shouldn't happen — idle has no store — but degrade gracefully.
            title = "Restricted"
            subtitle = "This app is restricted right now."
            bg = .black
            tint = .systemGray
            primary = "Request override"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: bg,
            icon: UIImage(systemName: "moon.zzz.fill"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .lightGray),
            primaryButtonLabel: primary.map {
                ShieldConfiguration.Label(text: $0, color: tint)
            },
            primaryButtonBackgroundColor: .clear,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Go to bed",
                color: .lightGray
            )
        )
    }

    /// `ShieldConfigurationDataSource` doesn't hand us the store name directly, so we
    /// read the most-recently-set phase from the App Group — the monitor extension
    /// writes this at every phase boundary, so it's always current.
    private func currentStoreName() -> String? {
        PhaseStoreName.name(for: PhaseState.current)
    }

    private func phase(from storeName: String?) -> Phase {
        switch storeName {
        case PhaseStoreName.amber:     return .amber
        case PhaseStoreName.windDown:  return .windDown
        case PhaseStoreName.lightsOut: return .lightsOut
        default:                       return .idle
        }
    }
}
