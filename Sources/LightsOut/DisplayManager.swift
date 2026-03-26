import CoreGraphics
import IOKit
import IOKit.graphics

class DisplayManager {
    private var originalBrightness: Float?

    func setWarmGamma() {
        let display = CGMainDisplayID()
        // Reduce blue significantly, green slightly, for a warm amber tone
        CGSetDisplayTransferByFormula(
            display,
            0, 1.0, 1.0,   // red: min, max, gamma
            0, 0.85, 1.0,  // green: slightly reduced
            0, 0.6, 1.0    // blue: heavily reduced = warm
        )
    }

    func resetGamma() {
        CGDisplayRestoreColorSyncSettings()
    }

    func setMinimumBrightness() {
        if originalBrightness == nil {
            originalBrightness = getCurrentBrightness()
        }
        setBrightness(0.0)
    }

    func restoreBrightness() {
        if let original = originalBrightness {
            setBrightness(original)
            originalBrightness = nil
        } else {
            setBrightness(0.5)
        }
    }

    func restoreAll() {
        resetGamma()
        restoreBrightness()
    }

    // MARK: - Private

    private func setBrightness(_ level: Float) {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, level)
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private func getCurrentBrightness() -> Float? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var brightness: Float = 0
        let kr = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        return kr == kIOReturnSuccess ? brightness : nil
    }
}
