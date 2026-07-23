import Testing
@testable import Offscreen

/// The music-vs-meeting distinction: a dedicated music player alone must not
/// hold breaks, while videos/calls (non-music media) and meetings (mic) do.
@Suite struct SmartPauseAudioTests {
    private typealias Audio = ProcessAudioMonitor.State

    @Test func musicAloneDoesNotHold() {
        let config = SmartPauseConfig() // ignoreMusicPlayers defaults true
        let state = Audio(micInUse: false, mediaPlaying: false, musicPlaying: true)
        #expect(SmartPauseController.shouldHoldForMedia(state, config: config) == false)
    }

    @Test func musicHoldsWhenExemptionOff() {
        var config = SmartPauseConfig()
        config.ignoreMusicPlayers = false
        let state = Audio(micInUse: false, mediaPlaying: false, musicPlaying: true)
        #expect(SmartPauseController.shouldHoldForMedia(state, config: config) == true)
    }

    @Test func videoAlwaysHolds() {
        let config = SmartPauseConfig()
        let state = Audio(micInUse: false, mediaPlaying: true, musicPlaying: false)
        #expect(SmartPauseController.shouldHoldForMedia(state, config: config) == true)
    }

    @Test func musicPlusVideoHolds() {
        // Music is exempt, but the video playing alongside it still holds.
        let config = SmartPauseConfig()
        let state = Audio(micInUse: false, mediaPlaying: true, musicPlaying: true)
        #expect(SmartPauseController.shouldHoldForMedia(state, config: config) == true)
    }
}
