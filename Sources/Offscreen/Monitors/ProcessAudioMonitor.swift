import CoreAudio
import Foundation

/// Watches CoreAudio *process objects* (macOS 14.4+) to see whether any
/// process is capturing the microphone or playing audio. Reading these HAL
/// properties never triggers the mic TCC prompt — nothing is captured.
final class ProcessAudioMonitor {
    struct State: Equatable {
        var micInUse = false
        /// Non–music-player audio output (video, calls, system audio, …).
        var mediaPlaying = false
        /// Output from a dedicated music player (Spotify, Apple Music, …),
        /// reported separately so it can be exempted from pausing breaks.
        var musicPlaying = false
    }

    /// Bundle-ID fragments identifying dedicated music players. Matched as a
    /// case-insensitive substring so helper processes (…spotify.helper) count.
    private static let musicPlayerHints = ["spotify", "apple.music", "apple.itunes"]

    private(set) var state = State()
    private var timer: Timer?
    private let onChange: (State) -> Void
    /// Require output to persist this many polls before reporting, so
    /// notification dings don't count as playback.
    private var mediaStreak = 0
    private var musicStreak = 0
    private let streakNeeded = 3

    init(onChange: @escaping (State) -> Void) {
        self.onChange = onChange
        timer = Poll.every(2.0) { [weak self] in self?.poll() }
    }

    private func poll() {
        var micInUse = false
        var mediaOut = false
        var musicOut = false
        var outputBundleIDs: [String] = []
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for object in processObjects() {
            let pid: pid_t = readScalar(object, kAudioProcessPropertyPID) ?? -1
            if pid == ownPID { continue } // ignore our own ambient sounds
            if (readScalar(object, kAudioProcessPropertyIsRunningInput) ?? UInt32(0)) != 0 {
                micInUse = true
            }
            if (readScalar(object, kAudioProcessPropertyIsRunningOutput) ?? UInt32(0)) != 0 {
                let bid = bundleID(object) ?? "pid:\(pid)"
                outputBundleIDs.append(bid)
                if Self.isMusicPlayer(bid) { musicOut = true } else { mediaOut = true }
            }
        }

        mediaStreak = mediaOut ? mediaStreak + 1 : 0
        musicStreak = musicOut ? musicStreak + 1 : 0
        let next = State(
            micInUse: micInUse,
            mediaPlaying: mediaStreak >= streakNeeded,
            musicPlaying: musicStreak >= streakNeeded
        )
        if next != state {
            state = next
            let sources = outputBundleIDs.joined(separator: ",")
            Log.monitors.info("audio: mic=\(next.micInUse) media=\(next.mediaPlaying) music=\(next.musicPlaying) out=[\(sources, privacy: .public)]")
            onChange(next)
        }
    }

    private static func isMusicPlayer(_ bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        return musicPlayerHints.contains { lower.contains($0) }
    }

    private func bundleID(_ object: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr,
              let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private func processObjects() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return [] }
        var objects = [AudioObjectID](
            repeating: 0, count: Int(dataSize) / MemoryLayout<AudioObjectID>.size
        )
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &objects) == noErr
        else { return [] }
        return objects
    }

    private func readScalar<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<T>.size)
        let storage = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { storage.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, storage) == noErr else {
            return nil
        }
        return storage.pointee
    }
}
