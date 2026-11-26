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

    /// Apps playing now or within the last `showGracePeriod` seconds. Rows
    /// stay a little after sound stops, so they don't flicker between songs.
    @Published private(set) var visibleApps: [AudioApp] = []
    @Published private(set) var settings: [String: MixerSetting] = Defaults[.mixerSettings]
    @Published private(set) var errorMessage: String?

    /// Every app with an audio process, shown or not, so a saved setting
    /// applies the moment a quiet app starts playing.
    private var apps: [AudioApp] = []
    private var lastActive: [String: Date] = [:]
    private let showGracePeriod: TimeInterval = 8
    /// Running taps and taps still starting on `tapQueue`.
    private var taps: [String: AppVolumeTap] = [:]
    /// Every `AppVolumeTap.start` and `stop` runs here, never on main: Core
    /// Audio can block them for as long as a macOS permission prompt is open.
    /// Serial, so a tap's stop always runs after its start.
    private let tapQueue = DispatchQueue(label: "local.notch.mixer.taps")
    private var outputDeviceID: AudioObjectID?
    private var timer: Timer?

    private init() {}

    func start() {
        outputDeviceID = defaultOutputDeviceID()
        watchSystem()
        refresh()
    }

    /// Removes every tap, so no app stays quiet or muted after the notch app quits.
    /// Waits at most 1 second, so a stuck Core Audio call can't hang quit. The
    /// system removes a process's taps when it exits anyway.
    func stop() {
        timer?.invalidate()
        timer = nil
        for tap in taps.values {
            tapQueue.async { tap.stop() }
        }
        taps = [:]
        let drained = DispatchWorkItem {}
        tapQueue.async(execute: drained)
        _ = drained.wait(timeout: .now() + 1)
    }

    func setting(for appID: String) -> MixerSetting {
        return settings[appID] ?? .full
    }

    /// Values near the top snap to 100%, so reaching full volume (and
    /// dropping the tap) is easy. Changing the volume unmutes.
    func setVolume(_ value: Double, for appID: String) {
        var setting = setting(for: appID)
        setting.volume = value >= 0.97 ? 1 : value
        setting.muted = false
        save(setting, for: appID)
    }

    func toggleMute(_ appID: String) {
        var setting = setting(for: appID)
        setting.muted.toggle()
        save(setting, for: appID)
    }

    private func save(_ setting: MixerSetting, for appID: String) {
        lastActive[appID] = Date()
        settings[appID] = setting.needsTap ? setting : nil
        Defaults[.mixerSettings] = settings
        applyTaps()
    }

    private func refresh() {
        apps = AudioAppScanner.scan()
        updateVisibleApps()
        applyTaps()
    }

    private func updateVisibleApps() {
        let now = Date()
        var visible: [AudioApp] = []
        for app in apps {
            if app.isPlaying {
                lastActive[app.id] = now
            }
            if let last = lastActive[app.id], now.timeIntervalSince(last) < showGracePeriod {
                visible.append(app)
            }
        }
        visibleApps = visible
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
            let sameProcesses = app.map { Set($0.processObjectIDs) } == Set(tap.processObjectIDs)
            if !stillNeeded || !sameProcesses {
                tapQueue.async { tap.stop() }
                taps[appID] = nil
            }
        }

        guard let outputDeviceID else {
            return
        }

        var startedAny = false
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
            // Recorded before it starts, so later passes don't start a second
            // tap for this app while this one waits.
            taps[app.id] = tap
            startTap(tap, appID: app.id, appName: app.name, outputDeviceID: outputDeviceID)
            startedAny = true
        }
        // A failed tap is removed from `taps`, so the next pass starts it
        // again. A pass that starts nothing has no failure left to show.
        if !startedAny {
            errorMessage = nil
        }
    }

    /// On failure, drops the tap so a later pass retries it, and shows why.
    private func startTap(_ tap: AppVolumeTap, appID: String, appName: String, outputDeviceID: AudioObjectID) {
        tapQueue.async {
            do {
                try tap.start(outputDeviceID: outputDeviceID)
            } catch {
                let message = "Couldn't change \(appName) (\(error.localizedDescription)). Allow Notch in System Settings > Privacy & Security > Screen & System Audio Recording."
                Task { @MainActor in
                    // Skip if this tap was stopped or replaced while it started.
                    if self.taps[appID] === tap {
                        self.taps[appID] = nil
                        self.errorMessage = message
                    }
                }
            }
        }
    }

    private func rebuildAllTaps() {
        for tap in taps.values {
            tapQueue.async { tap.stop() }
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
