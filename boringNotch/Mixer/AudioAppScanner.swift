import AppKit
import CoreAudio
import Darwin

/// One Mixer row: an app plus every audio process that belongs to it.
/// Apps like Discord, Chrome, and Safari play sound from helper processes,
/// so one app can own several Core Audio process objects.
struct AudioApp: Identifiable {
    let id: String
    let name: String
    let icon: NSImage
    var processObjectIDs: [AudioObjectID]
    var isPlaying: Bool
}

// macOS tracks which app is "responsible" for a helper process
// (for example Safari for its WebKit audio process). The function is not in
// a public header, so it is looked up at runtime and is optional.
private typealias ResponsiblePIDFunction = @convention(c) (pid_t) -> pid_t

private let responsiblePIDFunction: ResponsiblePIDFunction? = {
    let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
    guard let symbol = dlsym(defaultHandle, "responsibility_get_pid_responsible_for_pid") else {
        return nil
    }
    return unsafeBitCast(symbol, to: ResponsiblePIDFunction.self)
}()

enum AudioAppScanner {
    static func scan() -> [AudioApp] {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        let processList = readObjectList(systemObject, makeAddress(kAudioHardwarePropertyProcessObjectList))
        let ownPID = ProcessInfo.processInfo.processIdentifier

        var appsByID: [String: AudioApp] = [:]
        var order: [String] = []

        for processObjectID in processList {
            guard let pid = readValue(processObjectID, makeAddress(kAudioProcessPropertyPID), initial: pid_t(0)) else {
                continue
            }
            if pid == ownPID {
                continue
            }
            let runningValue = readValue(processObjectID, makeAddress(kAudioProcessPropertyIsRunningOutput), initial: UInt32(0))
            let isPlaying = (runningValue ?? 0) != 0

            guard let owner = findOwner(pid: pid, isPlaying: isPlaying) else {
                continue
            }

            if var existing = appsByID[owner.id] {
                existing.processObjectIDs.append(processObjectID)
                existing.isPlaying = existing.isPlaying || isPlaying
                appsByID[owner.id] = existing
            } else {
                var app = owner
                app.processObjectIDs = [processObjectID]
                app.isPlaying = isPlaying
                appsByID[owner.id] = app
                order.append(owner.id)
            }
        }

        var result: [AudioApp] = []
        for id in order {
            if let app = appsByID[id] {
                result.append(app)
            }
        }
        result.sort { first, second in
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
        return result
    }

    /// Finds the visible app that owns an audio process.
    /// Background tools (like `afplay`) are only listed while they are playing.
    private static func findOwner(pid: pid_t, isPlaying: Bool) -> AudioApp? {
        if let responsiblePIDFunction {
            let responsiblePID = responsiblePIDFunction(pid)
            if responsiblePID > 0, let app = regularApp(pid: responsiblePID) {
                return app
            }
        }
        if let app = regularApp(pid: pid) {
            return app
        }
        if let app = parentAppByBundlePrefix(pid: pid) {
            return app
        }
        if isPlaying {
            return commandLineTool(pid: pid)
        }
        return nil
    }

    private static func regularApp(pid: pid_t) -> AudioApp? {
        guard let running = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }
        return makeApp(running)
    }

    /// Fallback for helpers like "com.hnc.Discord.helper": match the app
    /// whose bundle ID is the start of the helper's bundle ID.
    private static func parentAppByBundlePrefix(pid: pid_t) -> AudioApp? {
        guard let helper = NSRunningApplication(processIdentifier: pid),
              let helperBundleID = helper.bundleIdentifier else {
            return nil
        }
        for running in NSWorkspace.shared.runningApplications {
            guard let bundleID = running.bundleIdentifier else {
                continue
            }
            if helperBundleID.hasPrefix(bundleID + "."), let app = makeApp(running) {
                return app
            }
        }
        return nil
    }

    private static func makeApp(_ running: NSRunningApplication) -> AudioApp? {
        if running.activationPolicy != .regular {
            return nil
        }
        guard let bundleID = running.bundleIdentifier else {
            return nil
        }
        let name = running.localizedName ?? bundleID
        let icon = running.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        return AudioApp(id: bundleID, name: name, icon: icon, processObjectIDs: [], isPlaying: false)
    }

    private static func commandLineTool(pid: pid_t) -> AudioApp? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        if length <= 0 {
            return nil
        }
        let name = String(cString: buffer)
        let icon = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) ?? NSImage()
        return AudioApp(id: "tool:" + name, name: name, icon: icon, processObjectIDs: [], isPlaying: false)
    }
}
