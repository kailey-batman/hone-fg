import Carbon
import AppKit

// Top-level C callback required by Carbon's InstallEventHandler
private func hotkeyEventCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    HotkeyService.shared.handleEvent(event)
    return noErr
}

class HotkeyService {
    static let shared = HotkeyService()

    private var registrations: [(ref: EventHotKeyRef, profileID: UUID, idHash: UInt32)] = []
    private var eventHandlerRef: EventHandlerRef?

    var onHotkeyTriggered: ((UUID) -> Void)?

    private init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventCallback,
            1, &spec, nil,
            &eventHandlerRef
        )
    }

    func registerAll(profiles: [Profile]) {
        for reg in registrations {
            UnregisterEventHotKey(reg.ref)
        }
        registrations.removeAll()

        for profile in profiles where profile.hotkey != nil {
            register(profile: profile)
        }
    }

    func unregister(profileID: UUID) {
        registrations.removeAll { entry in
            if entry.profileID == profileID {
                UnregisterEventHotKey(entry.ref)
                return true
            }
            return false
        }
    }

    private func register(profile: Profile) {
        guard let hotkey = profile.hotkey else { return }

        let idHash = UInt32(truncatingIfNeeded: abs(profile.id.hashValue))
        var keyID = EventHotKeyID(signature: 0x484F4E45, id: idHash) // "HONE"
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            keyID,
            GetApplicationEventTarget(),
            0, &ref
        )

        if status == noErr, let ref = ref {
            registrations.append((ref: ref, profileID: profile.id, idHash: idHash))
        }
    }

    func handleEvent(_ event: EventRef?) {
        guard let event = event else { return }

        var keyID = EventHotKeyID()
        GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &keyID
        )

        guard let match = registrations.first(where: { $0.idHash == keyID.id }) else { return }
        onHotkeyTriggered?(match.profileID)
    }
}
