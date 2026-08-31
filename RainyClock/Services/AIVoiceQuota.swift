import Foundation

/// How many spoken alarms a device may generate.
///
/// Three are free, and after that each one costs a rewarded video. The count
/// lives entirely on the device: there is no account to attach it to, and
/// keeping it local means the feature adds no data collection to a privacy label
/// that currently declares none.
///
/// A reinstall therefore resets it. That is a deliberate trade rather than an
/// oversight — the alternative is an identifier that survives deletion, which is
/// exactly the kind of tracking the app has spent two rejections getting out of.
@MainActor
enum AIVoiceQuota {
    static let freeGenerations = 3

    private static let usedKey = "aiVoiceGenerationsUsed"
    private static let creditsKey = "aiVoiceEarnedCredits"

    private static var used: Int {
        get { UserDefaults.standard.integer(forKey: usedKey) }
        set { UserDefaults.standard.set(newValue, forKey: usedKey) }
    }

    /// Generations bought with a completed rewarded video, and not yet spent.
    private static var credits: Int {
        get { UserDefaults.standard.integer(forKey: creditsKey) }
        set { UserDefaults.standard.set(newValue, forKey: creditsKey) }
    }

    static var freeRemaining: Int { max(0, freeGenerations - used) }

    static var remaining: Int { freeRemaining + credits }

    static var canGenerate: Bool { remaining > 0 }

    /// Spends one, taking the free allowance first so an earned credit is never
    /// burned while a free one is still available.
    static func consume() {
        if freeRemaining > 0 {
            used += 1
        } else if credits > 0 {
            credits -= 1
        }
    }

    /// Called the moment the ad network says the reward is earned — not when the
    /// audio arrives.
    ///
    /// This ordering is the whole point. Unity's Rewarded Ad Inventory Policy
    /// requires that a promised reward is actually delivered, and generation can
    /// fail afterwards for reasons that have nothing to do with the user: the
    /// model returns a 500, the content filter fires on a benign sentence, the
    /// network drops. Storing a credit means the retry is free and the promise is
    /// kept; handing over the audio instead would break it every time.
    static func grantCredit() {
        credits += 1
    }
}
