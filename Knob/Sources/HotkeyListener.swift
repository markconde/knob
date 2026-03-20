import Cocoa
import os

private let logger = Logger(subsystem: "com.mrkcnd.knob", category: "HotkeyListener")

final class HotkeyListener: @unchecked Sendable {
    var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onKeyDown: (@Sendable () -> Void)?
    var onKeyUp: (@Sendable () -> Void)?

    var isPressed = false

    @MainActor
    func start() {
        guard requestAccessibilityIfNeeded() else {
            logger.warning("Accessibility permission not granted. System prompt shown.")
            // Poll for permission grant
            Task { @MainActor [weak self] in
                while !AXIsProcessTrusted() {
                    try? await Task.sleep(for: .seconds(2))
                }
                logger.info("Accessibility permission granted after prompt.")
                self?.start()
            }
            return
        }

        logger.info("Accessibility permission granted. Setting up event tap.")

        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: selfPtr
        ) else {
            logger.error("Failed to create CGEvent tap.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("Event tap installed and enabled.")
    }

    @MainActor
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let listener = Unmanaged<HotkeyListener>.fromOpaque(userInfo).takeUnretainedValue()

    // Handle tap being disabled by the system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        logger.warning("Event tap was disabled by system, re-enabling.")
        if let tap = listener.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .flagsChanged else { return Unmanaged.passUnretained(event) }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags.rawValue
    NSLog("Knob: flagsChanged keycode=%d flags=0x%llx", keycode, flags)

    // Right Option keycode is 61
    guard keycode == 61 else { return Unmanaged.passUnretained(event) }

    let optionDown = event.flags.contains(.maskAlternate)

    if optionDown && !listener.isPressed {
        listener.isPressed = true
        NSLog("Knob: Right Option DOWN — starting recording")
        listener.onKeyDown?()
    } else if !optionDown && listener.isPressed {
        listener.isPressed = false
        NSLog("Knob: Right Option UP — stopping recording")
        listener.onKeyUp?()
    }

    return Unmanaged.passUnretained(event)
}

/// Wraps AXIsProcessTrustedWithOptions to avoid Swift 6 concurrency complaints
/// about kAXTrustedCheckOptionPrompt being mutable global state.
private nonisolated func requestAccessibilityIfNeeded() -> Bool {
    let promptKey = "AXTrustedCheckOptionPrompt" as CFString
    let options = [promptKey: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
