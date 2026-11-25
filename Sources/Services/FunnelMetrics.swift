import Foundation

enum FunnelEvent: String, CaseIterable {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case shiftLogged = "shift_logged"
    case scheduleImageShared = "schedule_image_shared"
    case pdfExported = "pdf_exported"
    case csvExportAttempted = "csv_export_attempted"
    case rotationPainted = "rotation_painted"
    case paywallViewed = "paywall_viewed"
    case paywallConverted = "paywall_converted"
    case abandonOfferShown = "abandon_offer_shown"
    case reviewGateShown = "review_gate_shown"
    case reviewPositiveTapped = "review_positive_tapped"
    case reviewFeedbackTapped = "review_feedback_tapped"
}

/// 100% local UserDefaults funnel counter (zero network calls, keeps App Store "Data Not Collected" intact).
final class FunnelMetrics {
    static let shared = FunnelMetrics()

    private let defaults: UserDefaults
    private let keyPrefix = "flatshift.funnel.v1."

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func record(_ event: FunnelEvent) {
        let key = keyPrefix + event.rawValue
        let next = defaults.integer(forKey: key) + 1
        defaults.set(next, forKey: key)
    }

    func count(for event: FunnelEvent) -> Int {
        defaults.integer(forKey: keyPrefix + event.rawValue)
    }

    func snapshot() -> [String: Int] {
        var result: [String: Int] = [:]
        for ev in FunnelEvent.allCases {
            result[ev.rawValue] = count(for: ev)
        }
        return result
    }

    func reset() {
        for ev in FunnelEvent.allCases {
            defaults.removeObject(forKey: keyPrefix + ev.rawValue)
        }
    }
}
