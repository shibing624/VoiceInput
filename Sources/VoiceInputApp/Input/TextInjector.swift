import AppKit
import Carbon

final class TextInjector {
    func inject(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        // Save current clipboard
        let oldContents = pasteboard.pasteboardItems?.compactMap { item -> (String, String)? in
            guard let type = item.types.first,
                  let data = item.string(forType: type) else { return nil }
            return (type.rawValue, data)
        }

        // Detect current input source
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let sourceID = unsafeBitCast(
            TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID),
            to: CFString.self
        ) as String

        let isCJK = ["SCIM", "TCIM", "Kotoeri", "Korean", "Pinyin", "Wubi", "Cangjie", "Zhuyin"]
            .contains(where: { sourceID.contains($0) })

        var originalSource: TISInputSource?
        if isCJK {
            originalSource = currentSource
            switchToASCIIInput()
            usleep(50_000) // 50ms for input source switch
        }

        // Set clipboard to our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        simulatePaste()

        // Restore original input source after delay
        if let source = originalSource {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                TISSelectInputSource(source)
            }
        }

        // Restore clipboard after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let oldContents = oldContents, !oldContents.isEmpty {
                pasteboard.clearContents()
                for (typeRaw, data) in oldContents {
                    pasteboard.setString(data, forType: NSPasteboard.PasteboardType(typeRaw))
                }
            }
        }
    }

    private func switchToASCIIInput() {
        let criteria = [
            kTISPropertyInputSourceCategory!: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceType!: kTISTypeKeyboardLayout!,
        ] as CFDictionary

        guard let sourceList = TISCreateInputSourceList(criteria, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }

        for source in sourceList {
            let sourceIDRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            guard sourceIDRef != nil else { continue }
            let sid = unsafeBitCast(sourceIDRef, to: CFString.self) as String
            if sid.contains("ABC") || sid.contains("US") || sid.contains("com.apple.keylayout.ABC") {
                TISSelectInputSource(source)
                return
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
