import CoreAudio
import Foundation

func makeAddress(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
}

/// Reads a fixed-size value such as UInt32, pid_t, or AudioObjectID.
func readValue<T>(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress, initial: T) -> T? {
    var address = address
    var value = initial
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &value) { pointer in
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
    }
    if status != noErr {
        return nil
    }
    return value
}

func readString(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
    var address = address
    var value: Unmanaged<CFString>? = nil
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = withUnsafeMutablePointer(to: &value) { pointer in
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
    }
    guard status == noErr, let value else {
        return nil
    }
    return value.takeRetainedValue() as String
}

func readObjectList(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> [AudioObjectID] {
    var address = address
    var size: UInt32 = 0
    if AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) != noErr {
        return []
    }
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    if count == 0 {
        return []
    }
    var list = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
    if AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &list) != noErr {
        return []
    }
    return list
}

func defaultOutputDeviceID() -> AudioObjectID? {
    let address = makeAddress(kAudioHardwarePropertyDefaultOutputDevice)
    let deviceID = readValue(AudioObjectID(kAudioObjectSystemObject), address, initial: kAudioObjectUnknown)
    if deviceID == nil || deviceID == kAudioObjectUnknown {
        return nil
    }
    return deviceID
}

struct CoreAudioError: LocalizedError {
    let step: String
    let status: OSStatus

    var errorDescription: String? {
        return "\(step) failed (code \(status))"
    }
}

func check(_ status: OSStatus, _ step: String) throws {
    if status != noErr {
        throw CoreAudioError(step: step, status: status)
    }
}
