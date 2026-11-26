import CoreAudio
import Foundation

/// Holds the gain the audio thread reads. A plain Float read is safe enough
/// here: the worst case is one buffer using the old value.
final class GainBox: @unchecked Sendable {
    var value: Float

    init(_ value: Float) {
        self.value = value
    }
}

/// Controls the volume of one app.
///
/// How it works:
/// 1. A process tap grabs the app's audio and mutes it at the source.
/// 2. A private aggregate device combines that tap (as input) with the
///    speakers (as output).
/// 3. Our callback copies input to output, multiplied by the gain.
final class AppVolumeTap {
    let processObjectIDs: [AudioObjectID]
    let gain: GainBox

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(processObjectIDs: [AudioObjectID], gain: Float) {
        self.processObjectIDs = processObjectIDs
        self.gain = GainBox(gain)
    }

    func start(outputDeviceID: AudioObjectID) throws {
        do {
            try createTap()
            try createAggregate(outputDeviceID: outputDeviceID)
            try startPlayback(outputDeviceID: outputDeviceID)
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown, let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    private var tapUUID = UUID()

    private func createTap() throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        description.uuid = tapUUID
        description.muteBehavior = .mutedWhenTapped
        description.isPrivate = true
        try check(AudioHardwareCreateProcessTap(description, &tapID), "Creating the audio tap")
    }

    private func createAggregate(outputDeviceID: AudioObjectID) throws {
        guard let outputUID = readString(outputDeviceID, makeAddress(kAudioDevicePropertyDeviceUID)) else {
            throw CoreAudioError(step: "Reading the output device", status: -1)
        }
        let settings: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Mixer Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUUID.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]
            ],
        ]
        try check(
            AudioHardwareCreateAggregateDevice(settings as CFDictionary, &aggregateID),
            "Creating the aggregate device"
        )
    }

    private func startPlayback(outputDeviceID: AudioObjectID) throws {
        // The aggregate's input buffers list the output device's own inputs
        // first (for example a headset mic), then the tap. Skip those.
        let inputStreams = readObjectList(
            outputDeviceID,
            makeAddress(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        )
        let tapBufferIndex = inputStreams.count
        let gain = self.gain

        let status = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) { _, inputData, _, outputData, _ in
            let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
            let outputs = UnsafeMutableAudioBufferListPointer(outputData)
            let currentGain = gain.value

            for outputIndex in 0..<outputs.count {
                let output = outputs[outputIndex]
                guard let outputBytes = output.mData else {
                    continue
                }
                memset(outputBytes, 0, Int(output.mDataByteSize))

                if outputIndex != 0 || tapBufferIndex >= inputs.count {
                    continue
                }
                let input = inputs[tapBufferIndex]
                guard let inputBytes = input.mData else {
                    continue
                }
                copyWithGain(input: input, inputBytes: inputBytes, output: output, outputBytes: outputBytes, gain: currentGain)
            }
        }
        try check(status, "Creating the audio callback")
        try check(AudioDeviceStart(aggregateID, ioProcID), "Starting audio")
    }
}

/// Copies interleaved Float32 audio, matching channels by position.
/// Extra output channels stay silent; extra input channels are dropped.
private func copyWithGain(
    input: AudioBuffer,
    inputBytes: UnsafeMutableRawPointer,
    output: AudioBuffer,
    outputBytes: UnsafeMutableRawPointer,
    gain: Float
) {
    let inputChannels = Int(max(input.mNumberChannels, 1))
    let outputChannels = Int(max(output.mNumberChannels, 1))
    let sampleSize = MemoryLayout<Float>.size
    let inputFrames = Int(input.mDataByteSize) / (sampleSize * inputChannels)
    let outputFrames = Int(output.mDataByteSize) / (sampleSize * outputChannels)
    let frames = min(inputFrames, outputFrames)
    let channels = min(inputChannels, outputChannels)

    let source = inputBytes.assumingMemoryBound(to: Float.self)
    let destination = outputBytes.assumingMemoryBound(to: Float.self)

    for frame in 0..<frames {
        for channel in 0..<channels {
            destination[frame * outputChannels + channel] = source[frame * inputChannels + channel] * gain
        }
    }
}
