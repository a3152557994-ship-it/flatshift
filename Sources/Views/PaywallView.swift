import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var triggerMessage: String? = nil
    var freeFallbackLabel: String? = nil
    var onFreeFallback: (() -> Void)? = nil

    @State private var selectedProductID: String = FlatShiftProductID.lifetime

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/terms.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Hero Banner
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "seal.fill")
                                .foregroundStyle(ShiftTheme.overtimeAmber)
                            Text(L10n.t("PAY ONCE · OWN FOREVER · ZERO ADS", "一次买断用终身 · 永久无广告"))
                                .font(.caption2.weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(ShiftTheme.overtimeAmber)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ShiftTheme.overtimeAmber.opacity(0.16))
                        .clipShape(Capsule())

                        Text(L10n.t("Skip $40–$50 Shift Apps.\nOwn FlatShift for $9.99.", "告别动辄几百元的排班软件\n一次买断，终身算清每分钱"))
                            .font(.system(size: 21, weight: .heavy))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        if let triggerMessage {
                            Text(triggerMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.84))
                        } else {
                            Text(L10n.t("Unlimited jobs, daily & weekly OT math, shift differentials, rotation painter, PDF & CSV exports.", "无限多份工作、日/周加班与夜班津贴精算、一键排班、无限 PDF 工资单与 CSV 表格导出。"))
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.82))
                        }

                        // Honest comparison anchor (ZERO competitor trademark names)
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("Typical Shift Apps", "常见倒班/工时软件"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.65))
                                Text(L10n.t("$30–$50+ / yr", "¥198–¥348 / 年"))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .strikethrough(true, color: .red)
                                    .foregroundStyle(Color.white.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("FlatShift Lifetime", "FlatShift 永久买断"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(ShiftTheme.overtimeAmber)
                                Text(store.displayPrice(for: FlatShiftProductID.lifetime) + L10n.t(" once", " 一次付清"))
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .background(ShiftTheme.cobalt.opacity(0.32))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(ShiftTheme.overtimeAmber, lineWidth: 1.2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(ShiftTheme.midnightIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // Benefits Checklist
                    VStack(alignment: .leading, spacing: 7) {
                        benefitRow("briefcase.fill", L10n.t("Unlimited jobs, side gigs & custom OT / differential rules", "无限多份工作与兼职，独立配置加班与夜班津贴"))
                        benefitRow("doc.richtext.fill", L10n.t("Unlimited clean PDF paycheck & timesheet reports", "无限导出高清 PDF 考勤工资核对单，去除底部标识"))
                        benefitRow("tablecells.fill", L10n.t("1-tap CSV payroll spreadsheet & full JSON offline backup", "一键导出 CSV 算薪表与本地全量 JSON 备份恢复"))
                        benefitRow("moon.stars.fill", L10n.t("100% offline, night-shift dark mode & zero ads forever", "100% 离线私密、夜班护眼深色模式、永久无广告"))
                    }
                    .shiftCard(padding: 12, cornerRadius: 14)

                    // 3 Plan Options
                    VStack(spacing: 8) {
                        planCard(
                            id: FlatShiftProductID.lifetime,
                            title: L10n.t("Lifetime Pro (Pay Once)", "永久买断版（一次付清）"),
                            subtitle: L10n.t("Own forever · No recurring bills · Best Value", "终身拥有 · 永不续费 · 最超值"),
                            price: store.displayPrice(for: FlatShiftProductID.lifetime),
                            period: L10n.t("one-time", "终身"),
                            badge: L10n.t("BEST VALUE", "首选买断")
                        )

                        planCard(
                            id: FlatShiftProductID.yearly,
                            title: L10n.t("Annual Pro (3-Day Free Trial)", "年度会员（含 3 天免费试用）"),
                            subtitle: L10n.t("Try free 3 days · Local reminder 24h before renewal", "先免费试 3 天 · 续费前 24 小时主动提醒"),
                            price: store.displayPrice(for: FlatShiftProductID.yearly),
                            period: L10n.t("/ year", "/ 年"),
                            badge: L10n.t("FREE TRIAL", "3天试用")
                        )

                        planCard(
                            id: FlatShiftProductID.monthly,
                            title: L10n.t("Monthly Pro", "月度灵活版"),
                            subtitle: L10n.t("Cancel anytime in Apple Account settings", "按月付、随时可在苹果订阅中一键取消"),
                            price: store.displayPrice(for: FlatShiftProductID.monthly),
                            period: L10n.t("/ month", "/ 月"),
                            badge: nil
                        )
                    }

                    // Primary CTA
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

                    // Non-hostile Free Exit
                    Button {
                        dismiss()
                        onFreeFallback?()
                    } label: {
                        Text(freeFallbackLabel ?? L10n.t("Continue Free (1 job, 2 PDFs/mo, zero ads)", "暂不升级，继续免费使用（每月2张PDF，零广告）"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ShiftTheme.muted)
                    }
                    .padding(.top, 2)

                    // Apple 3.1.2 Compliance Disclosure + Restore + Privacy + Terms
                    VStack(spacing: 8) {
                        HStack(spacing: 18) {
                            Button(L10n.t("Restore Purchases", "恢复购买")) {
                                Task { await store.restorePurchases() }
                            }
                            Link(L10n.t("Privacy Policy", "隐私政策"), destination: privacyURL)
                            Link(L10n.t("Terms of Use", "使用条款"), destination: termsURL)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ShiftTheme.ink)

                        Text(L10n.t(
                            "Lifetime Pro is a one-time non-consumable purchase. Annual (\(store.displayPrice(for: FlatShiftProductID.yearly))/year after 3-day free trial) and Monthly (\(store.displayPrice(for: FlatShiftProductID.monthly))/month) plans auto-renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple Account > Subscriptions.",
                            "永久买断版为一次性买断内购。年度会员（含3天免费试用，到期按 \(store.displayPrice(for: FlatShiftProductID.yearly))/年自动续订）与月度会员（\(store.displayPrice(for: FlatShiftProductID.monthly))/月自动续订）可随时在 iPhone「设置 > Apple 账户 > 订阅」中提前 24 小时取消。"
                        ))
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(ShiftTheme.canvas.ignoresSafeArea())
            .navigationTitle(L10n.t("FlatShift Pro", "升级 FlatShift Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Close", "关闭")) { dismiss() }
                }
            }
        }
    }

    private var ctaLabel: String {
        switch selectedProductID {
        case FlatShiftProductID.lifetime:
            return L10n.t(
                "Unlock Lifetime Pro — \(store.displayPrice(for: FlatShiftProductID.lifetime)) Once",
                "一次买断永久版 — \(store.displayPrice(for: FlatShiftProductID.lifetime))"
            )
        case FlatShiftProductID.yearly:
            return L10n.t(
                "Start 3-Day Free Trial (Then \(store.displayPrice(for: FlatShiftProductID.yearly))/yr)",
                "开启 3 天免费试用（随后 \(store.displayPrice(for: FlatShiftProductID.yearly))/年）"
            )
        default:
            return L10n.t(
                "Subscribe Monthly — \(store.displayPrice(for: FlatShiftProductID.monthly))/mo",
                "按月开通 — \(store.displayPrice(for: FlatShiftProductID.monthly))/月"
            )
        }
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(ShiftTheme.cobalt)
                .frame(width: 20)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(ShiftTheme.ink)
            Spacer()
        }
    }

    private func planCard(
        id: String,
        title: String,
        subtitle: String,
        price: String,
        period: String,
        badge: String?
    ) -> some View {
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.headline)
                    .foregroundStyle(selected ? ShiftTheme.cobalt : ShiftTheme.border)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ShiftTheme.ink)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8.5, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(id == FlatShiftProductID.lifetime ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt)
                                .foregroundStyle(id == FlatShiftProductID.lifetime ? ShiftTheme.midnightIndigo : .white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(ShiftTheme.ink)
                    Text(period)
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                }
            }
            .padding(11)
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
