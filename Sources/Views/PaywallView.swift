import StoreKit
import SwiftUI

enum PaywallRegionStyle: String, Equatable, CaseIterable {
    case angloROI
    case euPrivacyLifetime
    case eastAsiaDetail

    private static let euRegions: Set<String> = [
        "DE", "CH", "AT", "GB", "FR", "NL", "SE", "NO", "DK", "FI", "IE", "IT", "ES"
    ]

    private static let eastAsiaRegions: Set<String> = [
        "JP", "KR", "TW", "HK", "MO", "SG"
    ]

    static func resolve(regionCode: String?) -> PaywallRegionStyle {
        guard let code = regionCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !code.isEmpty else {
            return .angloROI
        }
        if euRegions.contains(code) {
            return .euPrivacyLifetime
        }
        if eastAsiaRegions.contains(code) {
            return .eastAsiaDetail
        }
        return .angloROI
    }

    static var current: PaywallRegionStyle {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ui_region"), idx + 1 < args.count {
            return resolve(regionCode: args[idx + 1])
        }
        return resolve(regionCode: Locale.current.region?.identifier)
    }

    var defaultSelectedProductID: String {
        switch self {
        case .angloROI:
            return FlatShiftProductID.yearly
        case .euPrivacyLifetime, .eastAsiaDetail:
            return FlatShiftProductID.lifetime
        }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var shiftStore: ShiftStore
    @Environment(\.dismiss) private var dismiss

    var triggerMessage: String? = nil
    var freeFallbackLabel: String? = nil
    var onFreeFallback: (() -> Void)? = nil
    var overrideRegionStyle: PaywallRegionStyle? = nil

    @State private var selectedProductID: String
    @State private var showAbandonOffer: Bool = false

    private let regionStyle: PaywallRegionStyle
    private let abandonOfferDefaultsKey = "flatshift.paywall.abandonOfferShown.v1"

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/terms.html")!
    private let supportMailURL = URL(string: "mailto:a3152557994@gmail.com?subject=FlatShift%20Support")!

    init(
        triggerMessage: String? = nil,
        freeFallbackLabel: String? = nil,
        onFreeFallback: (() -> Void)? = nil,
        overrideRegionStyle: PaywallRegionStyle? = nil
    ) {
        self.triggerMessage = triggerMessage
        self.freeFallbackLabel = freeFallbackLabel
        self.onFreeFallback = onFreeFallback
        self.overrideRegionStyle = overrideRegionStyle
        let resolved = overrideRegionStyle ?? PaywallRegionStyle.current
        self.regionStyle = resolved
        _selectedProductID = State(initialValue: resolved.defaultSelectedProductID)
    }

    /// Computes user's actual calculated OT & Differentials dollars for ROI anchoring.
    private var livePayAnchor: (otAndDiff: Double, netPay: Double, currency: String) {
        let range = PayEngine.payPeriodRange(cycle: shiftStore.preferences.payPeriodCycle, offset: 0)
        var summary = PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: range.start,
            periodEnd: range.end,
            defaultCurrency: shiftStore.preferences.currencySymbol
        )
        let periodExtra = PayEngine.roundCents(summary.totalOTCombinedPay + summary.totalDifferentialPay)
        if periodExtra <= 0 {
            let monthRange = PayEngine.payPeriodRange(cycle: .monthly, offset: 0)
            summary = PayEngine.summarize(
                shifts: shiftStore.shifts,
                jobs: shiftStore.jobs,
                periodStart: monthRange.start,
                periodEnd: monthRange.end,
                defaultCurrency: shiftStore.preferences.currencySymbol
            )
        }
        let extra = PayEngine.roundCents(summary.totalOTCombinedPay + summary.totalDifferentialPay)
        return (extra, summary.estimatedNetPay, summary.currencySymbol)
    }

    private var lifetimePrice: String { store.displayPrice(for: FlatShiftProductID.lifetime) }
    private var yearlyPrice: String { store.displayPrice(for: FlatShiftProductID.yearly) }
    private var monthlyPrice: String { store.displayPrice(for: FlatShiftProductID.monthly) }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 13) {
                        // MARK: - Regional Hero Banner
                        switch regionStyle {
                        case .angloROI:
                            angloHeroBanner
                        case .euPrivacyLifetime:
                            euPrivacyHeroBanner
                        case .eastAsiaDetail:
                            eastAsiaHeroBanner
                        }

                        // MARK: - Regional Feature Block / Matrix
                        if regionStyle == .eastAsiaDetail {
                            freeVsProMatrixCard
                        } else {
                            proBenefitsCard
                        }

                        // MARK: - Pricing Plan Options (Region-Ordered)
                        planStack

                        // MARK: - 3-Step Visual Blinkist Honest Trial Timeline (when Yearly is selected)
                        if selectedProductID == FlatShiftProductID.yearly {
                            blinkistTrialTimelineCard
                        }

                        // MARK: - Primary CTA
                        Button {
                            Task {
                                let ok = await store.purchase(selectedProductID)
                                if ok { dismiss() }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if store.isPurchasing {
                                    ProgressView().tint(.white)
                                }
                                Text(ctaLabel)
                                    .font(.headline.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(store.isPurchasing)

                        if let status = store.statusMessage {
                            Text(status)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(ShiftTheme.cobalt)
                                .multilineTextAlignment(.center)
                        }

                        // MARK: - Non-Hostile Free Exit
                        Button {
                            attemptDismiss(runFallback: true)
                        } label: {
                            Text(
                                freeFallbackLabel
                                    ?? L10n.t(
                                        "Continue Free (Calendar, Clock-In, 1 Job, Zero Ads)",
                                        "暂不升级，继续免费使用（排班打卡永久零广告）",
                                        "暫不升級，繼續免費使用（排班打卡永久零廣告）"
                                    )
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ShiftTheme.muted)
                            .multilineTextAlignment(.center)
                        }
                        .padding(.top, 2)

                        // MARK: - East Asia Trust Support & Cancellation Commitment
                        if regionStyle == .eastAsiaDetail {
                            eastAsiaTrustFooterCard
                        }

                        // MARK: - Apple 3.1.2 Disclosures + Restore + Privacy + Terms
                        complianceFooter
                    }
                    .padding(16)
                }
                .background(ShiftTheme.canvas.ignoresSafeArea())

                // MARK: - 1-Time Non-Annoying Abandon Offer Overlay (Max Once Ever, Zero Fake Timers)
                if showAbandonOffer {
                    abandonOfferOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: showAbandonOffer)
            .navigationTitle(L10n.t("FlatShift Pro", "升级 FlatShift Pro", "升級 FlatShift Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Close", "关闭", "關閉")) {
                        attemptDismiss(runFallback: false)
                    }
                }
            }
            .onAppear {
                FunnelMetrics.shared.record(.paywallViewed)
            }
        }
    }

    // MARK: - 1. Anglo ROI Hero Banner (US/CA/AU/NZ/default)
    private var angloHeroBanner: some View {
        let anchor = livePayAnchor
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(ShiftTheme.shiftMint)
                Text(L10n.t("PAYCHECK ACCURACY · 100% OFFLINE · ZERO ADS", "精准核算每一分加班费 · 离线零广告", "精準核算每分加班費 · 離線零廣告"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(ShiftTheme.shiftMint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ShiftTheme.shiftMint.opacity(0.16))
            .clipShape(Capsule())

            Text(
                L10n.t(
                    "Catch one missed 30-min OT error and FlatShift pays for itself.",
                    "哪怕少算一次 30 分钟加班费，FlatShift 就能帮你赚回好几倍。",
                    "只要抓出一次漏算 30 分鐘加班費，FlatShift 立刻回本。"
                )
            )
            .font(.system(size: 20, weight: .heavy))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)

            if anchor.otAndDiff > 0 {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("YOUR OT & DIFFERENTIALS", "您本期已计加班与津贴", "您本期已計加班費與津貼"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(ShiftTheme.overtimeAmber)
                        Text("+" + PayEngine.formatMoney(anchor.otAndDiff, symbol: anchor.currency))
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.t("EST. NET PAY", "预估税后到手", "預估稅後實領"))
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(ShiftTheme.shiftMint)
                        Text(PayEngine.formatMoney(anchor.netPay, symbol: anchor.currency))
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                .padding(11)
                .background(Color.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let triggerMessage {
                Text(triggerMessage)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.86))
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(ShiftTheme.midnightIndigo)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 2. EU Privacy & Lifetime Hero Banner (Calm, Factual, No Flashy Hype)
    private var euPrivacyHeroBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(ShiftTheme.shiftMint)
                Text(L10n.t("PRIVACY-FIRST · ONE-TIME OPTION", "本地隐私优先 · 支持永久买断", "私隱優先 · 支援永久買斷"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ShiftTheme.shiftMint)
            }

            Text(
                L10n.t(
                    "Own FlatShift Pro Forever",
                    "一次买断，终身拥有 FlatShift Pro",
                    "一次付清，永久買斷 FlatShift Pro"
                )
            )
            .font(.system(size: 21, weight: .bold))
            .foregroundStyle(ShiftTheme.ink)

            Text(
                L10n.t(
                    "100% Offline • No Hospital Account Required (GDPR) • Pay Once • Zero Ads",
                    "100% 离线本地存储 • 无需医院或单位账号 • 一次买断 • 永久零广告",
                    "100% 離線本機儲存 • 無須醫院或公司帳號 • 一次付清 • 永久零廣告"
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(ShiftTheme.cobalt)

            if let triggerMessage {
                Text(triggerMessage)
                    .font(.caption)
                    .foregroundStyle(ShiftTheme.muted)
            } else {
                Text(
                    L10n.t(
                        "All shift rosters, overtime rules, and paycheck numbers stay exclusively on your device. No tracking, no cloud login, and transparent pricing.",
                        "全部排班表、加班倍率与薪资明细均只保存在您的设备本地。无追踪、无强制登录，价格透明。",
                        "所有排班更表、加班規則與薪資明細皆僅存於本機。無追蹤、無須登入，收費透明。"
                    )
                )
                .font(.caption)
                .foregroundStyle(ShiftTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShiftTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ShiftTheme.border, lineWidth: 1)
        )
    }

    // MARK: - 3. East Asia High-Detail Trust Hero Banner (JP/KR/TW/HK/MO/SG)
    private var eastAsiaHeroBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(ShiftTheme.overtimeAmber)
                Text(
                    L10n.t(
                        "TRANSPARENT PRICING · 100% OFFLINE · ZERO ADS",
                        "透明定价 · 纯离线无广告 · 支持永久买断",
                        "透明定價 · 純離線零廣告 · 支援永久買斷"
                    )
                )
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ShiftTheme.overtimeAmber)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ShiftTheme.overtimeAmber.opacity(0.16))
            .clipShape(Capsule())

            Text(
                L10n.t(
                    "FlatShift Pro — Complete Shift & Overtime Suite",
                    "FlatShift Pro — 完整排班与加班费精算方案",
                    "FlatShift Pro — 完整排班更表與加班費試算方案"
                )
            )
            .font(.system(size: 19, weight: .heavy))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)

            Text(
                triggerMessage
                    ?? L10n.t(
                        "Compare every Free and Pro capability below before deciding. One-time Lifetime option included — no hidden renewals.",
                        "升级前可逐项核对免费版与专业版权益对比，提供永久买断与 7 天免费试用，绝无隐藏扣费。",
                        "升級前可逐項核對免費版與專業版功能對照表，提供永久買斷與 7 天免費試用，絕無隱藏扣款。"
                    )
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.white.opacity(0.84))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(ShiftTheme.midnightIndigo)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Pro Benefits Checklist (Anglo & EU)
    private var proBenefitsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            benefitRow(
                "percent",
                L10n.t(
                    "Detailed 1.5x / 2.0x OT, night & weekend differentials + Net Take-Home breakdown",
                    "完整 1.5x/2.0x 加班费、夜班与周末津贴及税后实发明细",
                    "完整 1.5x/2.0x 加班費試算、夜班津貼與稅後實領明細"
                )
            )
            benefitRow(
                "wand.and.stars",
                L10n.t(
                    "Full-year (up to 52 weeks) 1-tap Rotation Auto-Painter",
                    "全年（最长 52 周）一键倒班周期自动排班",
                    "全年（最長 52 週）一鍵輪班更表自動填入"
                )
            )
            benefitRow(
                "briefcase.fill",
                L10n.t(
                    "Unlimited jobs & side gigs with independent OT and tax rules",
                    "无限多份主副业管理，各自独立配置加班与扣税规则",
                    "無限份工作與兼職管理，各自獨立設定加班與稅率"
                )
            )
            benefitRow(
                "doc.richtext.fill",
                L10n.t(
                    "Unlimited clean PDF timesheets (no footer badge), CSV payroll exports & badge-free schedule images",
                    "无限导出无标识高清 PDF 工资核对单、CSV 明细表与纯净排班图",
                    "無限匯出無浮水印高清 PDF 薪資單、CSV 表格與純淨更表圖"
                )
            )
        }
        .shiftCard(padding: 13, cornerRadius: 14)
    }

    // MARK: - East Asia Free vs Pro Feature Comparison Matrix
    private var freeVsProMatrixCard: some View {
        let rows: [(String, String, String)] = [
            (
                L10n.t("Shift Calendar & Live Clock", "倒班日历与实时打卡", "排班更表與即時打卡"),
                L10n.t("Included", "免费含", "免費含"),
                L10n.t("Included", "包含", "包含")
            ),
            (
                L10n.t("Jobs & Side Gigs", "同时管理工作数", "同時管理工作數"),
                L10n.t("1 Job", "1 份", "1 份"),
                L10n.t("Unlimited", "无限制", "無上限")
            ),
            (
                L10n.t("Rotation Auto-Painter", "一键倒班排班长度", "一鍵輪班自動填入"),
                L10n.t("Up to 2 wks", "最长 2 周", "最長 2 週"),
                L10n.t("Full Year (52w)", "全年 52 周", "全年 52 週")
            ),
            (
                L10n.t("OT 1.5x/2x + Diff + Net", "加班费/夜班津贴/税后明细", "加班費試算/夜班津貼/實領"),
                L10n.t("Gross Only", "仅总税前", "僅基本總額"),
                L10n.t("Full Breakdown", "逐项精算", "逐項精算")
            ),
            (
                L10n.t("PDF & CSV Exports", "PDF 工资单与 CSV 导出", "PDF 薪資單與 CSV 匯出"),
                L10n.t("1 Lifetime PDF", "终身 1 次 PDF", "終身 1 次 PDF"),
                L10n.t("Unlimited Clean", "无限无水印", "無限無浮水印")
            ),
            (
                L10n.t("Share Schedule PNG", "一键分享排班图片", "一鍵分享更表圖片"),
                L10n.t("With Badge", "含底部标识", "含底部標示"),
                L10n.t("Clean / Optional", "纯净可隐藏", "純淨可隱藏")
            ),
        ]

        return VStack(spacing: 6) {
            HStack {
                Text(L10n.t("FEATURE COMPARISON", "功能权益对比", "功能權益對照表"))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(ShiftTheme.muted)
                Spacer()
                Text(L10n.t("FREE", "免费版", "免費版"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ShiftTheme.muted)
                    .frame(width: 72, alignment: .center)
                Text("PRO")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(ShiftTheme.cobalt)
                    .frame(width: 82, alignment: .center)
            }
            .padding(.bottom, 2)

            Divider()

            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 6) {
                    Text(row.0)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ShiftTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.1)
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                        .frame(width: 72, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(row.2)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ShiftTheme.shiftMint)
                        .frame(width: 82, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.vertical, 3)
                if idx < rows.count - 1 {
                    Divider().opacity(0.45)
                }
            }
        }
        .shiftCard(padding: 12, cornerRadius: 14)
    }

    // MARK: - Plan Cards Stack (Region-Ordered)
    @ViewBuilder
    private var planStack: some View {
        VStack(spacing: 9) {
            if regionStyle == .angloROI {
                // Anglo: Yearly (7-day trial, SAVE 83%) -> Lifetime (ONLY +$5 MORE) -> Monthly anchor
                yearlyPlanCard(badge: L10n.t("SAVE 83% · 7-DAY FREE", "省 83% · 7天免费试", "省 83% · 7天免費試"))
                lifetimePlanCard(
                    badge: L10n.t("ONLY +$5 MORE • OWN FOREVER", "仅多加少许 • 永久买断", "永久買斷 • 一次付清"),
                    calmStyle: false
                )
                monthlyPlanCard
            } else {
                // EU & East Asia: Lifetime Pro FIRST -> Yearly (7-day trial) -> Monthly
                lifetimePlanCard(
                    badge: regionStyle == .euPrivacyLifetime
                        ? L10n.t("ONE-TIME PURCHASE", "一次付清", "一次付清")
                        : L10n.t("BEST VALUE · OWN FOREVER", "首选永久买断", "首選永久買斷"),
                    calmStyle: regionStyle == .euPrivacyLifetime
                )
                yearlyPlanCard(badge: L10n.t("7-DAY FREE TRIAL", "7 天免费试用", "7 天免費試用"))
                monthlyPlanCard
            }
        }
    }

    private func lifetimePlanCard(badge: String, calmStyle: Bool) -> some View {
        planCard(
            id: FlatShiftProductID.lifetime,
            title: L10n.t("Lifetime Pro (Pay Once)", "永久买断版（一次付清）", "永久買斷版（一次付清）"),
            subtitle: calmStyle
                ? L10n.t("Single one-time payment · No recurring charges", "单次买断 · 永不续费 · 全功能解锁", "單次買斷 · 永不續費 · 全功能解鎖")
                : L10n.t("Own forever · No recurring bills · Family Sharing", "终身拥有 · 永不续费 · 支持家人共享", "終身擁有 · 永不續費 · 支援家人共享"),
            price: lifetimePrice,
            period: L10n.t("one-time", "终身", "永久"),
            badge: badge,
            badgeHighlight: !calmStyle
        )
    }

    private func yearlyPlanCard(badge: String) -> some View {
        planCard(
            id: FlatShiftProductID.yearly,
            title: L10n.t("Annual Pro (7-Day Free Trial)", "年度专业版（含 7 天免费试用）", "年度專業版（含 7 天免費試用）"),
            subtitle: L10n.t("Free for 7 days · Day-5 local reminder · Cancel anytime", "前 7 天 0 元体验 · 第 5 天提醒 · 随时取消", "前 7 天 $0 體驗 · 第 5 天提醒 · 隨時取消"),
            price: yearlyPrice,
            period: L10n.t("/ year", "/ 年", "/ 年"),
            badge: badge,
            badgeHighlight: false
        )
    }

    private var monthlyPlanCard: some View {
        planCard(
            id: FlatShiftProductID.monthly,
            title: L10n.t("Monthly Pro", "月度灵活版", "月度彈性方案"),
            subtitle: L10n.t("Flexible monthly billing · Cancel anytime", "按月计费 · 随时可在苹果订阅中一键取消", "按月計費 · 隨時可於 Apple 訂閱中取消"),
            price: monthlyPrice,
            period: L10n.t("/ month", "/ 月", "/ 月"),
            badge: nil,
            badgeHighlight: false
        )
    }

    // MARK: - 3-Step Visual Blinkist Honest Trial Timeline
    private var blinkistTrialTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("HOW YOUR 7-DAY FREE TRIAL WORKS", "7 天免费试用透明时间轴", "7 天免費試用透明時間軸"))
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(ShiftTheme.cobalt)

            timelineStep(
                icon: "lock.open.fill",
                color: ShiftTheme.shiftMint,
                title: L10n.t("Today: $0.00", "今天：¥0 免费开启", "今天：$0 免費體驗"),
                detail: L10n.t("Instant access to OT & Net breakdown, 52-week rotations & clean PDF/CSV exports.", "立即解锁完整加班与税后明细、全年自动排班与无限导出。", "立即解鎖完整加班費試算、全年自動更表與無限匯出。"),
                showLine: true
            )
            timelineStep(
                icon: "bell.badge.fill",
                color: ShiftTheme.overtimeAmber,
                title: L10n.t("Day 5: Friendly Reminder", "第 5 天：主动到期提醒", "第 5 天：貼心到期提醒"),
                detail: L10n.t("We send a local reminder 48 hours before your trial ends — zero surprise charges.", "续费前 48 小时通过本地通知提醒您，绝不悄悄扣款。", "續費前 48 小時本機通知提醒，絕不偷偷扣款。"),
                showLine: true
            )
            timelineStep(
                icon: "checkmark.circle.fill",
                color: ShiftTheme.cobalt,
                title: L10n.t("Day 7: Billed (\(yearlyPrice)/yr) · Cancel Anytime", "第 7 天：按 \(yearlyPrice)/年 计费 · 随时可取消", "第 7 天：依 \(yearlyPrice)/年 計費 · 隨時取消"),
                detail: L10n.t("Cancel anytime in 2 taps in iOS Settings > Apple Account > Subscriptions.", "若不满意，在到期前随时可在系统「订阅」中 2 步取消，分文不扣。", "若不滿意，到期前隨時於系統「訂閱項目」2 步取消，完全不扣款。"),
                showLine: false
            )
        }
        .shiftCard(padding: 13, cornerRadius: 14)
    }

    private func timelineStep(icon: String, color: Color, title: String, detail: String, showLine: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .clipShape(Circle())
                if showLine {
                    Rectangle()
                        .fill(ShiftTheme.border)
                        .frame(width: 2, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(ShiftTheme.ink)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(ShiftTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - East Asia Trust & Support Commitment Card
    private var eastAsiaTrustFooterCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                L10n.t("Clear Cancellation & Direct Indie Support", "清晰取消步骤与开发者直连售后", "清晰取消步驟與開發者直連支援"),
                systemImage: "envelope.badge.shield.half.filled"
            )
            .font(.caption.weight(.bold))
            .foregroundStyle(ShiftTheme.ink)

            Text(
                L10n.t(
                    "• Cancel subscription anytime: iOS Settings → Apple Account → Subscriptions → FlatShift.\n• Need help with pay rules or receipts? Email the developer directly:",
                    "• 随时取消路径：iPhone「设置」→「Apple 账户」→「订阅」→ FlatShift。\n• 遇到排班规则、算薪公式或购买问题，可直接发邮件给开发者本人：",
                    "• 隨時取消路徑：iPhone「設定」→「Apple 帳號」→「訂閱項目」→ FlatShift。\n• 如遇排班更表規則、加班費試算或購買問題，歡迎直接來信開發者："
                )
            )
            .font(.caption2)
            .foregroundStyle(ShiftTheme.muted)

            Link("a3152557994@gmail.com", destination: supportMailURL)
                .font(.caption.weight(.bold))
                .foregroundStyle(ShiftTheme.cobalt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shiftCard(padding: 12, cornerRadius: 12)
    }

    // MARK: - Apple 3.1.2 Compliance Footer
    private var complianceFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                Button(L10n.t("Restore Purchases", "恢复购买", "還原購買")) {
                    Task { await store.restorePurchases() }
                }
                Link(L10n.t("Privacy Policy", "隐私政策", "私隱政策"), destination: privacyURL)
                Link(L10n.t("Terms of Use", "使用条款", "使用條款"), destination: termsURL)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(ShiftTheme.ink)

            Text(
                L10n.t(
                    "Lifetime Pro (\(lifetimePrice)) is a one-time non-consumable purchase. Annual (\(yearlyPrice)/year after 7-day free trial) and Monthly (\(monthlyPrice)/month) plans auto-renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple Account > Subscriptions.",
                    "永久买断版（\(lifetimePrice)）为一次性买断内购。年度会员（含 7 天免费试用，到期按 \(yearlyPrice)/年自动续订）与月度会员（\(monthlyPrice)/月自动续订）可随时在 iPhone「设置 > Apple 账户 > 订阅」中提前 24 小时取消。",
                    "永久買斷版（\(lifetimePrice)）為一次性買斷項目。年度方案（含 7 天免費試用，到期後依 \(yearlyPrice)/年自動續訂）與月度方案（\(monthlyPrice)/月自動續訂）可隨時於 iPhone「設定 > Apple 帳號 > 訂閱項目」提前 24 小時取消。"
                )
            )
            .font(.caption2)
            .foregroundStyle(ShiftTheme.muted)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    // MARK: - 1-Time Non-Annoying Abandon Offer Overlay (Zero Fake Timers)
    private var abandonOfferOverlay: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture {
                    showAbandonOffer = false
                    dismiss()
                    onFreeFallback?()
                }

            VStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.title)
                    .foregroundStyle(ShiftTheme.cobalt)
                    .padding(12)
                    .background(ShiftTheme.cobaltSoft)
                    .clipShape(Circle())

                Text(
                    L10n.t(
                        "Try Pro Free for 7 Days — $0 Today",
                        "先免费体验 7 天 Pro — 今天 ¥0 扣费",
                        "免費試用 7 天 Pro — 今天 $0 扣款"
                    )
                )
                .font(.headline.weight(.heavy))
                .foregroundStyle(ShiftTheme.ink)
                .multilineTextAlignment(.center)

                Text(
                    L10n.t(
                        "Verify your next paycheck with full OT & differential breakdown and clean PDFs. We'll remind you on Day 5 before anything is billed — or own it forever once for \(lifetimePrice).",
                        "用完整加班费与税后明细核对一次真实工资单，第 5 天主动提醒，随时可取消；或 \(lifetimePrice) 一次永久买断。此提示仅显示一次。",
                        "先用完整加班費試算與實領明細核對一次薪資單，第 5 天主動提醒、隨時可取消；或 \(lifetimePrice) 一次永久買斷。此提示僅顯示一次。"
                    )
                )
                .font(.caption)
                .foregroundStyle(ShiftTheme.muted)
                .multilineTextAlignment(.center)

                Button {
                    showAbandonOffer = false
                    selectedProductID = FlatShiftProductID.yearly
                    Task {
                        let ok = await store.purchase(FlatShiftProductID.yearly)
                        if ok { dismiss() }
                    }
                } label: {
                    Text(L10n.t("Start 7-Day Free Trial ($0 Today)", "开启 7 天免费试用（今日 ¥0）", "開始 7 天免費試用（今日 $0）"))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(ShiftTheme.cobalt)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    showAbandonOffer = false
                    selectedProductID = FlatShiftProductID.lifetime
                    Task {
                        let ok = await store.purchase(FlatShiftProductID.lifetime)
                        if ok { dismiss() }
                    }
                } label: {
                    Text(L10n.t("Or Pay Once Forever — \(lifetimePrice)", "或一次永久买断 — \(lifetimePrice)", "或一次永久買斷 — \(lifetimePrice)"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ShiftTheme.cobalt)
                }

                Button {
                    showAbandonOffer = false
                    dismiss()
                    onFreeFallback?()
                } label: {
                    Text(L10n.t("No thanks, continue free", "不了，继续免费使用", "不用了，繼續免費使用"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ShiftTheme.muted)
                }
                .padding(.top, 2)
            }
            .padding(20)
            .background(ShiftTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ShiftTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private func attemptDismiss(runFallback: Bool) {
        let isDemo = ProcessInfo.processInfo.arguments.contains("-ui_demo_screen")
        let alreadyShown = UserDefaults.standard.bool(forKey: abandonOfferDefaultsKey)
        if !store.isPro && !isDemo && !alreadyShown && !showAbandonOffer {
            UserDefaults.standard.set(true, forKey: abandonOfferDefaultsKey)
            FunnelMetrics.shared.record(.abandonOfferShown)
            showAbandonOffer = true
            return
        }
        dismiss()
        if runFallback {
            onFreeFallback?()
        }
    }

    private var ctaLabel: String {
        switch selectedProductID {
        case FlatShiftProductID.lifetime:
            return L10n.t(
                "Unlock Lifetime Pro — \(lifetimePrice) Once",
                "一次买断永久版 — \(lifetimePrice)",
                "一次永久買斷 — \(lifetimePrice)"
            )
        case FlatShiftProductID.yearly:
            return L10n.t(
                "Start 7-Day Free Trial (Then \(yearlyPrice)/yr)",
                "开启 7 天免费试用（随后 \(yearlyPrice)/年）",
                "開始 7 天免費試用（隨後 \(yearlyPrice)/年）"
            )
        default:
            return L10n.t(
                "Subscribe Monthly — \(monthlyPrice)/mo",
                "按月开通 — \(monthlyPrice)/月",
                "按月訂閱 — \(monthlyPrice)/月"
            )
        }
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(ShiftTheme.cobalt)
                .frame(width: 20, height: 18)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(ShiftTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func planCard(
        id: String,
        title: String,
        subtitle: String,
        price: String,
        period: String,
        badge: String?,
        badgeHighlight: Bool
    ) -> some View {
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.headline)
                    .foregroundStyle(selected ? ShiftTheme.cobalt : ShiftTheme.border)

                VStack(alignment: .leading, spacing: 3) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 8.5, weight: .heavy))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(badgeHighlight ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt)
                            .foregroundStyle(badgeHighlight ? ShiftTheme.midnightIndigo : .white)
                            .clipShape(Capsule())
                    }
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ShiftTheme.ink)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(ShiftTheme.ink)
                    Text(period)
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                }
            }
            .padding(12)
            .background(selected ? ShiftTheme.cobaltSoft : ShiftTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? ShiftTheme.cobalt : ShiftTheme.border, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
