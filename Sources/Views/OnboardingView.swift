import SwiftUI

/// Day-0 30-second Shift & Paycheck Onboarding:
/// 1) Pick shift template (3x12 Nurse, 2-2-3 Panama, Standard 5x8)
/// 2) Adjust hourly rate slider -> live monthly gross & OT estimate
/// 3) Soft paywall preview with clear "Continue Free (Zero Ads)" escape hatch
struct OnboardingView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager

    var onFinish: (_ openPaywallAfter: Bool) -> Void

    @State private var step: Int = 0
    @State private var selectedPattern: RotationPattern = .nurse3x12
    @State private var hourlyRate: Double = L10n.currentLanguage == .zhHant ? 220 : (L10n.isChinese ? 65 : 44)
    @State private var includeNightDiff: Bool = true

    private let templates: [RotationPattern] = [.nurse3x12, .panama223, .monFri8h]

    private var currency: String {
        L10n.t("$", "¥", "HK$")
    }

    private var rateRange: ClosedRange<Double> {
        switch L10n.currentLanguage {
        case .zhHant: return 60...500
        case .zhHans: return 20...300
        case .en: return 15...120
        }
    }

    private var rateStep: Double {
        L10n.currentLanguage == .en ? 1 : 5
    }

    private var defaultNightDiff: Double {
        switch L10n.currentLanguage {
        case .zhHant: return 35.0
        case .zhHans: return 12.0
        case .en: return 4.5
        }
    }

    /// Real PayEngine 4-week projection based on user's chosen template & hourly rate.
    private var monthlyPreview: PayPeriodSummary {
        let previewJob = JobProfile(
            name: selectedPattern.title,
            role: "",
            colorHex: "#2563EB",
            hourlyRate: hourlyRate,
            defaultUnpaidBreakMinutes: 30,
            dailyOTThresholdHours: 8.0,
            dailyOTMultiplier: 1.5,
            dailyDoubleTimeThresholdHours: 12.0,
            dailyDoubleTimeMultiplier: 2.0,
            weeklyOTThresholdHours: 40.0,
            weeklyOTMultiplier: 1.5,
            nightDifferentialPerHour: includeNightDiff ? defaultNightDiff : 0.0,
            weekendDifferentialPerHour: L10n.currentLanguage == .zhHant ? 25 : (L10n.isChinese ? 8 : 3.0),
            holidayMultiplier: 2.0,
            estimatedTaxRatePercent: L10n.isChinese ? 12.0 : 22.0,
            currencySymbol: currency
        )
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let generated = PayEngine.generateRotationShifts(
            pattern: selectedPattern,
            job: previewJob,
            startDate: start,
            weeks: 4,
            calendar: cal
        )
        let end = cal.date(byAdding: .day, value: 29, to: start) ?? start.addingTimeInterval(29 * 86_400)
        return PayEngine.summarize(
            shifts: generated,
            jobs: [previewJob],
            periodStart: start,
            periodEnd: end,
            defaultCurrency: currency,
            calendar: cal
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step Progress Indicator
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= step ? ShiftTheme.cobalt : ShiftTheme.border)
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 18) {
                        if step == 0 {
                            stepOneTemplatePicker
                        } else if step == 1 {
                            stepTwoHourlyRateAndPreview
                        } else {
                            stepThreeSoftPaywallReady
                        }
                    }
                    .padding(20)
                }

                // Bottom Action Bar
                VStack(spacing: 10) {
                    if step < 2 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                step += 1
                            }
                        } label: {
                            Text(
                                step == 0
                                    ? L10n.t("Next: Estimate My Paycheck", "下一步：试算月度薪资", "下一步：試算每月薪資")
                                    : L10n.t("Build My Schedule & Paycheck", "生成我的排班与工资预估", "產生我的排班更表與薪資試算")
                            )
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        if step > 0 {
                            Button(L10n.t("Back", "返回上一步", "返回上一步")) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    step -= 1
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ShiftTheme.muted)
                        }
                    } else {
                        Button {
                            completeSetup(openPaywall: true)
                        } label: {
                            Text(
                                L10n.t(
                                    "Unlock Full OT & Net Pay (7-Day Free Trial)",
                                    "解锁完整加班与税后明细（7天免费试）",
                                    "解鎖完整加班費與實領明細（7天免費試）"
                                )
                            )
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            completeSetup(openPaywall: false)
                        } label: {
                            Text(L10n.t("Continue Free (Zero Ads)", "继续免费使用（永久零广告）", "繼續免費使用（永久零廣告）"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ShiftTheme.muted)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(ShiftTheme.card)
                .overlay(alignment: .top) { Divider() }
            }
            .background(ShiftTheme.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("Skip", "跳过", "略過")) {
                        completeSetup(openPaywall: false)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ShiftTheme.muted)
                }
            }
            .onAppear {
                FunnelMetrics.shared.record(.onboardingStarted)
            }
        }
    }

    // MARK: - Step 1: Pick Shift Template
    private var stepOneTemplatePicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("30-SECOND SETUP", "30 秒极速建表", "30 秒快速設定"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(ShiftTheme.cobalt)
                Text(L10n.t("Pick your shift rotation", "选择您的排班倒班方式", "選擇您的排班輪班模式"))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(ShiftTheme.ink)
                Text(L10n.t("We'll paint your first 2 weeks automatically. 100% offline, zero ads, no account needed.", "系统将自动为您填入前 2 周班表。纯离线运行、零广告、无需注册。", "系統將自動為您填入前 2 週更表。純離線運行、零廣告、無須註冊。"))
                    .font(.subheadline)
                    .foregroundStyle(ShiftTheme.muted)
            }

            VStack(spacing: 12) {
                ForEach(templates) { pat in
                    let active = selectedPattern == pat
                    Button {
                        selectedPattern = pat
                        includeNightDiff = pat.cycle.contains(.night)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(active ? ShiftTheme.cobalt : ShiftTheme.border)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(pat.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(ShiftTheme.ink)
                                Text(pat.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(ShiftTheme.muted)
                                HStack(spacing: 4) {
                                    ForEach(0..<min(14, pat.cycle.count), id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(pat.cycle[i].color)
                                            .frame(width: 14, height: 7)
                                    }
                                }
                                .padding(.top, 2)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(active ? ShiftTheme.cobaltSoft : ShiftTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(active ? ShiftTheme.cobalt : ShiftTheme.border, lineWidth: active ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Hourly Rate Slider + Instant Monthly Gross & OT Preview
    private var stepTwoHourlyRateAndPreview: some View {
        let preview = monthlyPreview
        let otAndDiff = PayEngine.roundCents(preview.totalOTCombinedPay + preview.totalDifferentialPay)

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("STEP 2 OF 3", "第 2 / 3 步", "第 2 / 3 步"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(ShiftTheme.cobalt)
                Text(L10n.t("What's your base hourly rate?", "设置您的基础时薪", "設定您的基本時薪"))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(ShiftTheme.ink)
                Text(L10n.t("Slide to see your instant 4-week gross pay and overtime preview.", "拖动滑块，实时预览 4 周税前应发与加班津贴估算。", "拖動滑桿，即時預覽 4 週稅前應發與加班費試算。"))
                    .font(.subheadline)
                    .foregroundStyle(ShiftTheme.muted)
            }

            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.t("Hourly Rate", "基础时薪", "基本時薪"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ShiftTheme.muted)
                    Spacer()
                    Text("\(PayEngine.formatMoney(hourlyRate, symbol: currency))/hr")
                        .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(ShiftTheme.cobalt)
                }

                Slider(value: $hourlyRate, in: rateRange, step: rateStep)
                    .tint(ShiftTheme.cobalt)

                Toggle(isOn: $includeNightDiff) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(ShiftTheme.nightViolet)
                        Text(
                            L10n.t(
                                "Include Night Differential (+\(PayEngine.formatMoney(defaultNightDiff, symbol: currency))/hr)",
                                "包含夜班津贴 (+\(PayEngine.formatMoney(defaultNightDiff, symbol: currency))/时)",
                                "包含夜班津貼 (+\(PayEngine.formatMoney(defaultNightDiff, symbol: currency))/時)"
                            )
                        )
                        .font(.caption.weight(.semibold))
                    }
                }
            }
            .shiftCard(padding: 16, cornerRadius: 16)

            // Instant Live Paycheck Preview Card
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.t("EST. 4-WEEK PAYCHECK PREVIEW", "4 周薪资实时试算预览", "4 週薪資即時試算預覽"))
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(ShiftTheme.shiftMint)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("Monthly Gross", "月度税前应发", "月度稅前總額"))
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(PayEngine.formatMoney(preview.totalGrossPay, symbol: currency))
                            .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.t("OT + Differentials", "加班与夜班津贴", "加班費與津貼"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ShiftTheme.overtimeAmber)
                        Text("+" + PayEngine.formatMoney(otAndDiff, symbol: currency))
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(ShiftTheme.overtimeAmber)
                    }
                }

                HStack(spacing: 12) {
                    Label(
                        L10n.t("\(preview.totalShiftsWorked) shifts", "\(preview.totalShiftsWorked) 个班次", "\(preview.totalShiftsWorked) 個更次"),
                        systemImage: "calendar"
                    )
                    Label(
                        PayEngine.formatHours(preview.totalHours),
                        systemImage: "clock.fill"
                    )
                    if preview.totalOTCombinedHours > 0 {
                        Label(
                            L10n.t("\(PayEngine.formatHours(preview.totalOTCombinedHours)) OT", "加班 \(PayEngine.formatHours(preview.totalOTCombinedHours))", "加班 \(PayEngine.formatHours(preview.totalOTCombinedHours))"),
                            systemImage: "bolt.fill"
                        )
                        .foregroundStyle(ShiftTheme.overtimeAmber)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(18)
            .background(ShiftTheme.midnightIndigo)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Step 3: Ready Summary & Soft Paywall Choice
    private var stepThreeSoftPaywallReady: some View {
        let preview = monthlyPreview
        let otAndDiff = PayEngine.roundCents(preview.totalOTCombinedPay + preview.totalDifferentialPay)

        return VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundStyle(ShiftTheme.shiftMint)
                .padding(.top, 8)

            Text(L10n.t("Your Shift Calendar Is Ready!", "您的倒班日历已配置就绪！", "您的排班更表已準備就緒！"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(ShiftTheme.ink)
                .multilineTextAlignment(.center)

            Text(
                L10n.t(
                    "Based on \(selectedPattern.title) at \(PayEngine.formatMoney(hourlyRate, symbol: currency))/hr, your projected 4-week pay is \(PayEngine.formatMoney(preview.totalGrossPay, symbol: currency)) (including +\(PayEngine.formatMoney(otAndDiff, symbol: currency)) in OT & differentials).",
                    "按「\(selectedPattern.title)」与 \(PayEngine.formatMoney(hourlyRate, symbol: currency))/时 测算，您 4 周预估应发 \(PayEngine.formatMoney(preview.totalGrossPay, symbol: currency))（其中含加班与津贴 +\(PayEngine.formatMoney(otAndDiff, symbol: currency))）。",
                    "依「\(selectedPattern.title)」與時薪 \(PayEngine.formatMoney(hourlyRate, symbol: currency)) 試算，您 4 週預估薪資為 \(PayEngine.formatMoney(preview.totalGrossPay, symbol: currency))（內含加班費與津貼 +\(PayEngine.formatMoney(otAndDiff, symbol: currency))）。"
                )
            )
            .font(.subheadline)
            .foregroundStyle(ShiftTheme.muted)
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(
                    icon: "checkmark.circle.fill",
                    color: ShiftTheme.shiftMint,
                    text: L10n.t("Free Forever: Monthly Shift Calendar, Live Clock-In/Out, 1 Job, Gross Hours & Pay, Share Schedule Image — Zero Ads.", "永久免费：月度倒班日历、实时打卡、1 份工作、工时与基本税前汇总、一键分享排班图 — 零广告。", "永久免費：月度排班更表、即時打卡、1 份工作、工時與基本總薪、一鍵分享更表圖 — 零廣告。")
                )
                summaryRow(
                    icon: "sparkles",
                    color: ShiftTheme.cobalt,
                    text: L10n.t("FlatShift Pro: Full 1.5x/2.0x OT & Net Take-Home breakdown, 52-week auto-painter, unlimited jobs & unlimited clean PDF/CSV exports.", "FlatShift Pro：完整 1.5x/2.0x 加班与税后实发精算、全年自动排班、无限工作数与无限高清无水印 PDF/CSV 导出。", "FlatShift Pro：完整 1.5x/2.0x 加班費試算與稅後實領明細、全年自動排班、無限份工作與無限無浮水印 PDF/CSV 匯出。")
                )
            }
            .shiftCard(padding: 15, cornerRadius: 16)
        }
    }

    private func summaryRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(ShiftTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func completeSetup(openPaywall: Bool) {
        shiftStore.applyOnboardingSetup(
            pattern: selectedPattern,
            hourlyRate: hourlyRate,
            includeNightDiff: includeNightDiff
        )
        FunnelMetrics.shared.record(.onboardingCompleted)
        onFinish(openPaywall)
    }
}
