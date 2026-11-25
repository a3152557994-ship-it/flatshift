import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager

    @State private var selectedTab: Int
    @State private var showPaywall: Bool = false
    @State private var paywallMessage: String? = nil
    @State private var paywallFallbackLabel: String? = nil
    @State private var paywallFallbackAction: (() -> Void)? = nil
    @State private var didApplyLaunchDemo = false

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
                Label(L10n.t("Clock & Pay", "打卡算薪"), systemImage: "clock.badge.checkmark.fill")
            }
            .tag(0)

            CalendarTabView(onOpenPaywall: { msg in
                openPaywall(message: msg)
            })
            .tabItem {
                Label(L10n.t("Calendar", "倒班日历"), systemImage: "calendar")
            }
            .tag(1)

            PaycheckTabView(onOpenPaywall: { msg, fallbackLabel, fallbackAction in
                openPaywall(message: msg, fallbackLabel: fallbackLabel, fallbackAction: fallbackAction)
            })
            .tabItem {
                Label(L10n.t("Paycheck", "工资单"), systemImage: "doc.text.magnifyingglass")
            }
            .tag(2)

            JobsSettingsView(onOpenPaywall: { msg in
                openPaywall(message: msg)
            })
            .tabItem {
                Label(L10n.t("Jobs & Settings", "工作设置"), systemImage: "briefcase.fill")
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
        .onAppear {
            applyDemoScreenIfNeeded()
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

    private func applyDemoScreenIfNeeded() {
        guard !didApplyLaunchDemo else { return }
        didApplyLaunchDemo = true
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-ui_demo_screen"), idx + 1 < args.count else { return }
        if args[idx + 1] == "paywall" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                openPaywall(
                    message: nil,
                    fallbackLabel: L10n.t("Continue with Free Plan (2 PDFs/mo)", "继续使用免费版（每月2张PDF）"),
                    fallbackAction: {}
                )
            }
        }
    }
}
