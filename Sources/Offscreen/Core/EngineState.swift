import Foundation

enum BreakKind: Equatable, Hashable, Sendable {
    case short
    case long
    case planned(name: String, durationSeconds: Int)

    var title: String {
        switch self {
        case .short: "Short Break"
        case .long: "Long Break"
        case .planned(let name, _): name
        }
    }
}

enum InactiveReason: Equatable, Sendable {
    case paused(until: Date?) // nil = until manually resumed
    case outsideOfficeHours
}

enum EnginePhase: Equatable, Sendable {
    case inactive(InactiveReason)
    case working
    case preBreak
    case holding // break is due but deferred by a hold reason
    case inBreak
    case idlePaused

    var isInactive: Bool { if case .inactive = self { return true }; return false }
}

/// Why a due break is being held back (Smart Pause signals).
enum HoldReason: String, CaseIterable, Hashable, Sendable {
    case camera
    case microphone
    case mediaPlayback
    case screenShared
    case fullscreenApp
    case focusApp
    case typing
    case snoozed

    var label: String {
        switch self {
        case .camera: "Camera in use"
        case .microphone: "Microphone in use"
        case .mediaPlayback: "Media playing"
        case .screenShared: "Screen shared"
        case .fullscreenApp: "Fullscreen app"
        case .focusApp: "Focus app"
        case .typing: "Typing"
        case .snoozed: "Snoozed"
        }
    }
}

enum BreakEndReason: Equatable, Sendable {
    case completed
    case skipped
    case endedEarly
    case autoIdle // user was away long enough that it counted as a break
}

enum EngineEvent {
    case tick
    case phaseChanged(old: EnginePhase, new: EnginePhase)
    case preBreakStarted(kind: BreakKind)
    case breakStarted(kind: BreakKind)
    case breakEnded(kind: BreakKind, reason: BreakEndReason, elapsedSeconds: Double)
    case snoozed(seconds: Int, used: Int, limit: Int)
}
