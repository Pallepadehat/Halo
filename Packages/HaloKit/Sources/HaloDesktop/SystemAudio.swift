#if os(macOS)
import AudioToolbox
import CoreAudio

/// The default output device's volume and mute, via Core Audio.
public enum SystemAudio {
    public struct State: Sendable, Equatable {
        public let volume: Double?
        public let isMuted: Bool
        public let deviceName: String?
    }

    public static func current() -> State {
        guard let device = defaultOutput() else { return State(volume: nil, isMuted: false, deviceName: nil) }
        let volume: Float32? = read(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        let muted: UInt32? = read(device, kAudioDevicePropertyMute)
        return State(volume: volume.map(Double.init), isMuted: muted == 1, deviceName: name(of: device))
    }

    public static func setVolume(_ volume: Double) {
        guard let device = defaultOutput() else { return }
        write(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, Float32(min(max(volume, 0), 1)))
        if volume > 0 { write(device, kAudioDevicePropertyMute, UInt32(0)) }
    }

    public static func toggleMute() {
        guard let device = defaultOutput() else { return }
        let muted: UInt32 = read(device, kAudioDevicePropertyMute) ?? 0
        write(device, kAudioDevicePropertyMute, UInt32(muted == 0 ? 1 : 0))
    }

    // MARK: - Core Audio plumbing

    private static func defaultOutput() -> AudioObjectID? {
        let device: AudioObjectID? = read(
            AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal
        )
        return device.flatMap { $0 == kAudioObjectUnknown ? nil : $0 }
    }

    private static func name(of device: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func read<Value: BitwiseCopyable>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput
    ) -> Value? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var size = UInt32(MemoryLayout<Value>.size)
        let pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.pointee
    }

    private static func write<Value: BitwiseCopyable>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: Value) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain
        )
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(object, &address),
              AudioObjectIsPropertySettable(object, &address, &settable) == noErr, settable.boolValue
        else { return }
        var value = value
        AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<Value>.size), &value)
    }
}
#endif
