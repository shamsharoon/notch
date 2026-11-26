import CoreAudio
import Defaults
import Foundation

/// One app's saved Mixer setting. An app at full volume and not muted has
/// no entry and no tap.
struct MixerSetting: Codable, Hashable, Defaults.Serializable {
    var volume: Double
    var muted: Bool

    static let full = MixerSetting(volume: 1, muted: false)

    var needsTap: Bool {
        return muted || volume < 1
    }

    var gain: Float {
        return muted ? 0 : Float(volume)
    }
}

extension Defaults.Keys {
    /// Keyed by bundle ID.
    static let mixerSettings = Key<[String: MixerSetting]>("mixerSettings", default: [:])
}

@MainActor
final class MixerModel: ObservableObject {
    static let shared = MixerModel()

    @Published private(set) var apps: [AudioApp] = []
    @Published private(set) var settings: [String: MixerSetting] = Defaults[.mixerSettings]
    @Published private(set) var errorMessage: String?

    private var taps: [String: AppVolumeTap] = [:]
    private var outputDeviceID: AudioObjectID?
    private var timer: Timer?

    private init() {}

    func start() {
        outputDeviceID = defaultOutputDeviceID()
        watchSystem()
        refresh()
    }

    /// Removes every tap, so no app stays quiet or muted after the notch app quits.
    func stop() {
        timer?.invalidate()
        timer = nil
        for tap in taps.values {
            tap.stop()
        }
        taps = [:]
    }

    func setting(for appID: String) -> MixerSetting {
        return settings[appID] ?? .full
    }

    func setVolume(_ value: Double, for appID: String) {
        var setting = setting(for: appID)
        setting.volume = value >= 0.995 ? 1 : value
        save(setting, for: appID)
    }

    func toggleMute(_ appID: String) {
        var setting = setting(for: appID)
        setting.muted.toggle()
        save(setting, for: appID)
    }

    private func save(_ setting: MixerSetting, for appID: String) {
        settings[appID] = setting.needsTap ? setting : nil
        Defaults[.mixerSettings] = settings
        applyTaps()
    }

    private func refresh() {
        var scanned = AudioAppScanner.scan()
        scanned.sort { first, second in
            if first.isPlaying != second.isPlaying {
                return first.isPlaying
            }
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
        apps = scanned
        applyTaps()
    }

    // MARK: - Taps

    private func applyTaps() {
        var appsByID: [String: AudioApp] = [:]
        for app in apps {
            appsByID[app.id] = app
        }

        for (appID, tap) in taps {
            let app = appsByID[appID]
            let stillNeeded = app != nil && setting(for: appID).needsTap
            let sameProcesses = app?.processObjectIDs == tap.processObjectIDs
            if !stillNeeded || !sameProcesses {
                tap.stop()
                taps[appID] = nil
            }
        }

        guard let outputDeviceID else {
            return
        }

        var failure: String?
        for app in apps {
            let setting = setting(for: app.id)
            if !setting.needsTap {
                continue
            }
            if let tap = taps[app.id] {
                tap.gain.value = setting.gain
                continue
            }
            let tap = AppVolumeTap(processObjectIDs: app.processObjectIDs, gain: setting.gain)
            do {
                try tap.start(outputDeviceID: outputDeviceID)
                taps[app.id] = tap
            } catch {
                failure = "Couldn't change \(app.name) (\(error.localizedDescription)). Allow Notch in System Settings > Privacy & Security > Screen & System Audio Recording."
            }
        }
        errorMessage = failure
    }

    private func rebuildAllTaps() {
        for tap in taps.values {
            tap.stop()
        }
        taps = [:]
        applyTaps()
    }

    // MARK: - Watching for changes

    private func watchSystem() {
        let systemObject = AudioObjectID(kAudioObjectSystemObject)

        // Apps starting or quitting: apply saved settings right away.
        var processAddress = makeAddress(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(systemObject, &processAddress, DispatchQueue.main) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }

        // Headphones plugged in, etc: point every tap at the new output.
        var deviceAddress = makeAddress(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(systemObject, &deviceAddress, DispatchQueue.main) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }
                self.outputDeviceID = defaultOutputDeviceID()
                self.rebuildAllTaps()
            }
        }

        // "Is playing" has no cheap system-wide notification, so check every 2 seconds.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }
}
