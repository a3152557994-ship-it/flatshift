import Foundation
import SwiftUI

/// Gentle happy-path review prompt gate:
/// Triggers after 1st shared schedule image, 1st exported PDF, or 3rd logged shift.
/// Respects a strict 90-day cooldown and never interrupts screenshot/demo runs.
@MainActor
final class ReviewPromptManager: ObservableObject {
    static let cooldownDays: Double = 90
    static let shiftsRequiredForTrigger: Int = 3
    static let feedbackMailtoURL = URL(string: "mailto:a3152557994@gmail.com?subject=FlatShift%20Feedback")!

    @Published var isShowingPrompt: Bool = false

    private let defaults: UserDefaults
    private let metrics: FunnelMetrics
    private let lastShownKey = "flatshift.review.lastShownAt.v1"
    private let loggedShiftsKey = "flatshift.review.loggedShifts.v1"
    private let sharedScheduleKey = "flatshift.review.sharedScheduleCount.v1"
    private let exportedPDFKey = "flatshift.review.exportedPDFCount.v1"

    init(userDefaults: UserDefaults = .standard, metrics: FunnelMetrics? = nil) {
        self.defaults = userDefaults
        self.metrics = metrics ?? FunnelMetrics(userDefaults: userDefaults)
    }

    func recordScheduleImageShared(now: Date = Date()) {
        metrics.record(.scheduleImageShared)
        let count = defaults.integer(forKey: sharedScheduleKey) + 1
        defaults.set(count, forKey: sharedScheduleKey)
        if count == 1 {
            presentIfEligible(now: now)
        }
    }

    func recordPDFExported(now: Date = Date()) {
        metrics.record(.pdfExported)
        let count = defaults.integer(forKey: exportedPDFKey) + 1
        defaults.set(count, forKey: exportedPDFKey)
        if count == 1 {
            presentIfEligible(now: now)
        }
    }

    func recordShiftLogged(now: Date = Date()) {
        metrics.record(.shiftLogged)
        let count = defaults.integer(forKey: loggedShiftsKey) + 1
        defaults.set(count, forKey: loggedShiftsKey)
        if count == Self.shiftsRequiredForTrigger {
            presentIfEligible(now: now)
        }
    }

    func isWithinCooldown(now: Date = Date()) -> Bool {
        let lastTs = defaults.double(forKey: lastShownKey)
        guard lastTs > 0 else { return false }
        let elapsed = now.timeIntervalSince1970 - lastTs
        return elapsed < (Self.cooldownDays * 86_400)
    }

    @discardableResult
    func presentIfEligible(now: Date = Date()) -> Bool {
        if ProcessInfo.processInfo.arguments.contains("-ui_demo_screen") {
            return false
        }
        guard !isWithinCooldown(now: now) else { return false }
        defaults.set(now.timeIntervalSince1970, forKey: lastShownKey)
        metrics.record(.reviewGateShown)
        isShowingPrompt = true
        return true
    }

    func markPositiveRatingTapped() {
        metrics.record(.reviewPositiveTapped)
        isShowingPrompt = false
    }

    func markFeedbackTapped() {
        metrics.record(.reviewFeedbackTapped)
        isShowingPrompt = false
    }

    func dismissPrompt() {
        isShowingPrompt = false
    }
}
