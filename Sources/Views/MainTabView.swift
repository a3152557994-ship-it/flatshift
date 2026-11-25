import StoreKit
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var reviewManager: ReviewPromptManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    @State private var selectedTab: Int
    @State private var showPaywall: Bool = false
    @State private var paywallMessage: String? = nil
    @State private var paywallFallbackLabel: String? = nil
    @State private var paywallFallbackAction: (() -> Void)? = nil
    @State private var didApplyLaunchDemo = false
    @State private var showOnboarding: Bool = false

    private let onboardingCompletedKey = "flatshift.onboarding.completed.v1"

    init() {
        let args = ProcessInfo.processInfo.arguments
        var initial = 0
        if let idx = args.firstIndex(of: "-ui_demo_screen"), idx + 1 < args.count {
            switch args[idx + 1] {
            case "calendar": initial = 1
            case "paycheck": initial = 2
            case "jobs": initial = 3
            default: initial = 0
            }
        }
        _selectedTab = State(initialValue: initial)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ClockHomeView(onOpenPaywall: { msg in
                openPaywall(message: msg)
            })
            .tabItem {
                Label(L10n.t("Clock & Pay", "打卡算薪", "打卡算薪"), systemImage: "clock.badge.checkmark.fill")
            }
            .tag(0)

            CalendarTabView(onOpenPaywall: { msg in
                openPaywall(message: msg)
            })
            .tabItem {
                Label(L10n.t("Calendar", "倒班日历", "排班更表"), systemImage: "calendar")
            }
            .tag(1)

            PaycheckTabView(onOpenPaywall: { msg, fallbackLabel, fallbackAction in
                openPaywall(message: msg, fallbackLabel: fallbackLabel, fallbackAction: fallbackAction)
            })
            .tabItem {
                Label(L10n.t("Paycheck", "工资单", "薪資單"), systemImage: "doc.text.magnifyingglass")
            }
            .tag(2)

            JobsSettingsView(onOpenPaywall: { msg in
                openPaywall(message: msg)
            })
            .tabItem {
                Label(L10n.t("Jobs & Settings", "工作设置", "工作設定"), systemImage: "briefcase.fill")
            }
            .tag(3)
        }
        .tint(ShiftTheme.cobalt)
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                triggerMessage: paywallMessage,
                freeFallbackLabel: paywallFallbackLabel,
                onFreeFallback: paywallFallbackAction
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { openPaywallAfter in
                UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
                showOnboarding = false
                if openPaywallAfter {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        openPaywall(
                            message: nil,
                            fallbackLabel: L10n.t("Continue Free (Zero Ads)", "继续免费使用（零广告）", "繼續免費使用（零廣告）"),
                            fallbackAction: nil
                        )
                    }
                }
            }
        }
        .alert(
            L10n.t("Enjoying FlatShift?", "喜欢 FlatShift 倒班算薪吗？", "喜歡 FlatShift 更表算薪嗎？"),
            isPresented: $reviewManager.isShowingPrompt
        ) {
            Button(L10n.t("Yes, love it!", "好用，给个好评！", "好用，給予好評！")) {
                reviewManager.markPositiveRatingTapped()
                requestReview()
            }
            Button(L10n.t("Send Feedback", "提建议 / 反馈问题", "傳送意見回饋")) {
                reviewManager.markFeedbackTapped()
                openURL(ReviewPromptManager.feedbackMailtoURL)
            }
            Button(L10n.t("Not Now", "暂不", "稍後再說"), role: .cancel) {
                reviewManager.dismissPrompt()
            }
        } message: {
            Text(
                L10n.t(
                    "FlatShift is 100% offline with zero ads — built by an indie developer for shift workers. A quick rating helps others find it!",
                    "FlatShift 坚持 100% 本地离线与零广告。如果您觉得好用，欢迎给个简短评分支持独立开发！",
                    "FlatShift 堅持 100% 本機離線與零廣告。如果您覺得好用，歡迎給予好評支持獨立開發者！"
                )
            )
        }
        .onAppear {
            applyLaunchFlowIfNeeded()
        }
    }

    private func openPaywall(
        message: String? = nil,
        fallbackLabel: String? = nil,
        fallbackAction: (() -> Void)? = nil
    ) {
        paywallMessage = message
        paywallFallbackLabel = fallbackLabel
        paywallFallbackAction = fallbackAction
        showPaywall = true
    }

    private func applyLaunchFlowIfNeeded() {
        guard !didApplyLaunchDemo else { return }
        didApplyLaunchDemo = true

        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ui_demo_screen"), idx + 1 < args.count {
            // Skip onboarding in screenshot/demo automation
            if args[idx + 1] == "paywall" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    openPaywall(
                        message: nil,
                        fallbackLabel: L10n.t("Continue Free (Zero Ads)", "继续免费使用（永久零广告）", "繼續免費使用（永久零廣告）"),
                        fallbackAction: {}
                    )
                }
            }
            return
        }

        // Day-0 30-second onboarding shown once on first launch
        if !UserDefaults.standard.bool(forKey: onboardingCompletedKey) {
            showOnboarding = true
        }
    }
}
