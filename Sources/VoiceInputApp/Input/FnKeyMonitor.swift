import Cocoa
import Carbon

/// Monitors Fn key (built-in & external keyboards) and Right Command key globally.
/// Both keys behave identically: press = onFnDown, release = onFnUp.
///
/// Key support matrix:
///   • MacBook built-in keyboard  → Fn key  (maskSecondaryFn flag)
///   • Apple Magic Keyboard        → Fn key  (maskSecondaryFn flag)
///   • External keyboards with Fn  → Fn key  (maskSecondaryFn, if firmware forwards it)
///   • Any keyboard                → Right Command (keyCode 54) — universal fallback
final class FnKeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    /// Tracks which key initiated the current recording session.
    /// nil = not recording via keyboard.
    private enum TriggerSource { case fn, rightCommand }
    private var triggerSource: TriggerSource?

    private var isTriggered: Bool { triggerSource != nil }

    private static let kVKRightCommand: Int64 = 54

    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else {
                    return Unmanaged.passRetained(event)
                }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it gets disabled by the system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        // While recording via Right Command, swallow stray keyDown events that
        // would otherwise fire global shortcuts (e.g. Cmd+Space).
        if type == .keyDown, triggerSource == .rightCommand {
            let flags = event.flags
            let onlyCmd = flags.contains(.maskCommand)
                && !flags.contains(.maskShift)
                && !flags.contains(.maskAlternate)
                && !flags.contains(.maskControl)
            if onlyCmd { return nil }
        }

        guard type == .flagsChanged else {
            return Unmanaged.passRetained(event)
        }

        let flags   = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // ── Fn key ────────────────────────────────────────────────────────────
        let fnNowPressed = flags.contains(.maskSecondaryFn)

        if fnNowPressed, triggerSource == nil {
            triggerSource = .fn
            DispatchQueue.main.async { [weak self] in self?.onFnDown?() }
            return nil  // suppress emoji picker
        }

        if !fnNowPressed, triggerSource == .fn {
            triggerSource = nil
            DispatchQueue.main.async { [weak self] in self?.onFnUp?() }
            return nil
        }

        // ── Right Command (keyCode 54) ────────────────────────────────────────
        // Used as universal fallback for keyboards whose Fn key is handled in
        // firmware and never reaches the OS.
        if keyCode == FnKeyMonitor.kVKRightCommand {
            let cmdNowPressed = flags.contains(.maskCommand)

            if cmdNowPressed, triggerSource == nil {
                triggerSource = .rightCommand
                DispatchQueue.main.async { [weak self] in self?.onFnDown?() }
                return nil  // suppress Right Command action
            }

            if !cmdNowPressed, triggerSource == .rightCommand {
                triggerSource = nil
                DispatchQueue.main.async { [weak self] in self?.onFnUp?() }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }

    /// Prompt the user with system Accessibility dialog (only triggers once per app install).
    static func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Silent check — no system dialog, just returns current trust state.
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
}
