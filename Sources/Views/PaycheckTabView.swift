import PDFKit
import SwiftUI
import UIKit

struct PaycheckTabView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var reviewManager: ReviewPromptManager

    var onOpenPaywall: (String?, String?, (() -> Void)?) -> Void

    @State private var periodOffset: Int = 0
    @State private var filterJobId: UUID? = nil
    @State private var shareFileURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var showFullScreenPDF: Bool = false
    @State private var statusBanner: String? = nil

    private var periodRange: (start: Date, end: Date) {
        PayEngine.payPeriodRange(cycle: shiftStore.preferences.payPeriodCycle, offset: periodOffset)
    }

    private var summary: PayPeriodSummary {
        PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: periodRange.start,
            periodEnd: periodRange.end,
            filterJobId: filterJobId,
            defaultCurrency: shiftStore.preferences.currencySymbol
        )
    }

    private var activeJobTitle: String {
        if let fid = filterJobId, let j = shiftStore.job(for: fid) {
            return j.name
        }
        return shiftStore.jobs.count == 1
            ? (shiftStore.jobs.first?.name ?? L10n.t("All Jobs", "全部工作", "全部工作"))
            : L10n.t("All Jobs Combined", "全部工作汇总", "全部工作彙總")
    }

    private var livePDFData: Data {
        PDFTimesheetRenderer.renderPDFData(
            summary: summary,
            jobTitle: activeJobTitle,
            employeeName: shiftStore.preferences.employeeName,
            use24HourTime: shiftStore.preferences.use24HourTime,
            includeBrandingFooter: !store.isPro
        )
    }

    private var periodLabel: String {
        let df = DateFormatter()
        df.locale = L10n.locale
        df.dateFormat = L10n.t("MMM d", "M月d日", "M月d日")
        return "\(df.string(from: periodRange.start)) – \(df.string(from: periodRange.end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // MARK: - Pay Period & Job Filter Controls
                    periodSelectorCard

                    // MARK: - Interactive Paycheck Reconciliation Card (Free Gross + Pro Detailed OT/Diff/Net)
                    reconciliationCard

                    if let statusBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ShiftTheme.shiftMint)
                            Text(statusBanner)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShiftTheme.ink)
                            Spacer()
                        }
                        .padding(11)
                        .background(ShiftTheme.shiftMint.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // MARK: - Live Vector PDFKit Timesheet Preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(
                                L10n.t("Live PDF Timesheet Preview", "实时矢量 PDF 工资核对单预览", "即時向量 PDF 薪資單預覽"),
                                systemImage: "doc.richtext.fill"
                            )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(ShiftTheme.ink)
                            Spacer()
                            Button {
                                showFullScreenPDF = true
                            } label: {
                                Label(L10n.t("Expand", "全屏查看", "全螢幕檢視"), systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ShiftTheme.cobalt)
                            }
                        }

                        PDFKitTimesheetView(data: livePDFData)
                            .frame(height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ShiftTheme.border, lineWidth: 1)
                            )
                    }
                    .shiftCard(padding: 14, cornerRadius: 16)

                    // MARK: - Export & Print Action Deck
                    exportActionDeck
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(ShiftTheme.canvas.ignoresSafeArea())
            .navigationTitle(L10n.t("Paycheck & Timesheet", "工资单与导出", "薪資單與匯出"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet, onDismiss: {
                if shareFileURL?.pathExtension.lowercased() == "pdf" {
                    reviewManager.recordPDFExported()
                }
            }) {
                if let url = shareFileURL {
                    ActivityShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showFullScreenPDF) {
                NavigationStack {
                    PDFKitTimesheetView(data: livePDFData)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle(L10n.t("PDF Timesheet", "PDF 工资核对单", "PDF 薪資核對單"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10n.t("Done", "完成", "完成")) { showFullScreenPDF = false }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showFullScreenPDF = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        handlePDFShare()
                                    }
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                }
            }
        }
    }

    private var periodSelectorCard: some View {
        VStack(spacing: 10) {
            HStack {
                Button { periodOffset -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(ShiftTheme.cardElevated)
                        .foregroundStyle(ShiftTheme.ink)
                        .clipShape(Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(periodLabel)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(ShiftTheme.ink)
                    Text("\(shiftStore.preferences.payPeriodCycle.title) · \(summary.totalShiftsWorked) \(L10n.t("shifts", "班", "更"))")
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                }
                Spacer()
                Button { periodOffset += 1 } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(ShiftTheme.cardElevated)
                        .foregroundStyle(ShiftTheme.ink)
                        .clipShape(Circle())
                }
            }

            if shiftStore.jobs.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        jobPill(title: L10n.t("All Jobs", "全部工作", "全部工作"), active: filterJobId == nil) { filterJobId = nil }
                        ForEach(shiftStore.jobs) { job in
                            jobPill(title: job.name, active: filterJobId == job.id) { filterJobId = job.id }
                        }
                    }
                }
            }
        }
        .shiftCard(padding: 12, cornerRadius: 14)
    }

    private func jobPill(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(active ? ShiftTheme.cobalt : ShiftTheme.cardElevated)
                .foregroundStyle(active ? .white : ShiftTheme.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var reconciliationCard: some View {
        let otAndDiffTotal = PayEngine.roundCents(summary.totalOTCombinedPay + summary.totalDifferentialPay)

        return VStack(spacing: 10) {
            if store.isPro {
                // Full Pro Reconciliation Header & Detailed Line-by-Line Breakdown
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("ESTIMATED NET TAKE-HOME", "预估税后到手", "預估稅後實領"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ShiftTheme.shiftMint)
                        Text(PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol))
                            .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(ShiftTheme.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.t("TOTAL PAID HOURS", "计薪总工时", "計薪總工時"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ShiftTheme.muted)
                        Text(PayEngine.formatHoursDecimal(summary.totalHours) + " h")
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(ShiftTheme.cobalt)
                    }
                }

                Divider()

                payLine(
                    L10n.t("Regular Pay (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)", "正常工时薪资 (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)", "基本工時薪資 (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)"),
                    PayEngine.formatMoney(summary.totalRegularPay, symbol: summary.currencySymbol),
                    ShiftTheme.ink
                )
                payLine(
                    L10n.t("Overtime 1.5x (\(PayEngine.formatHoursDecimal(summary.totalOvertimeHours))h)", "1.5倍加班费 (\(PayEngine.formatHoursDecimal(summary.totalOvertimeHours))h)", "1.5倍加班費 (\(PayEngine.formatHoursDecimal(summary.totalOvertimeHours))h)"),
                    PayEngine.formatMoney(summary.totalOvertimePay, symbol: summary.currencySymbol),
                    ShiftTheme.overtimeAmber
                )
                if summary.totalDoubleTimeHours > 0 {
                    payLine(
                        L10n.t("Double-Time 2.0x (\(PayEngine.formatHoursDecimal(summary.totalDoubleTimeHours))h)", "2.0倍双倍加班 (\(PayEngine.formatHoursDecimal(summary.totalDoubleTimeHours))h)", "2.0倍雙倍加班 (\(PayEngine.formatHoursDecimal(summary.totalDoubleTimeHours))h)"),
                        PayEngine.formatMoney(summary.totalDoubleTimePay, symbol: summary.currencySymbol),
                        ShiftTheme.overtimeAmber
                    )
                }
                payLine(
                    L10n.t("Night & Weekend Differentials", "夜班与周末津贴", "夜班與週末津貼"),
                    "+" + PayEngine.formatMoney(summary.totalDifferentialPay, symbol: summary.currencySymbol),
                    ShiftTheme.nightViolet
                )

                Divider()

                payLine(
                    L10n.t("Gross Pay", "税前应发总额", "稅前應發總額"),
                    PayEngine.formatMoney(summary.totalGrossPay, symbol: summary.currencySymbol),
                    ShiftTheme.ink,
                    bold: true
                )
                payLine(
                    L10n.t("Est. Tax Withholding (\(String(format: "%.1f%%", summary.effectiveTaxPercent)))", "预估个税社保 (\(String(format: "%.1f%%", summary.effectiveTaxPercent)))", "預估稅金扣繳 (\(String(format: "%.1f%%", summary.effectiveTaxPercent)))"),
                    "-" + PayEngine.formatMoney(summary.estimatedTax, symbol: summary.currencySymbol),
                    ShiftTheme.muted
                )
            } else {
                // Free Tier: Clean Basic Gross Pay + Paid Hours FREE;
                // Crisp preview of real calculated OT & Net dollars + Inline Unlock CTA on detailed 1.5x/2.0x/Diff/Net breakdown!
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("BASIC GROSS PAY (FREE)", "基本税前应发（免费）", "基本稅前應發（免費）"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ShiftTheme.cobalt)
                        Text(PayEngine.formatMoney(summary.totalGrossPay, symbol: summary.currencySymbol))
                            .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(ShiftTheme.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.t("TOTAL PAID HOURS", "计薪总工时", "計薪總工時"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ShiftTheme.muted)
                        Text(PayEngine.formatHoursDecimal(summary.totalHours) + " h")
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(ShiftTheme.cobalt)
                    }
                }

                Divider()

                payLine(
                    L10n.t("Base Regular Hours (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)", "基础正常工时 (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)", "基本正常工時 (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)"),
                    PayEngine.formatMoney(summary.totalRegularPay, symbol: summary.currencySymbol),
                    ShiftTheme.ink
                )

                // Loss-aversion crisp preview + locked detailed breakdown
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                otAndDiffTotal > 0
                                    ? L10n.t(
                                        "\(PayEngine.formatMoney(otAndDiffTotal, symbol: summary.currencySymbol)) OT & diff earned",
                                        "本期含 \(PayEngine.formatMoney(otAndDiffTotal, symbol: summary.currencySymbol)) 加班与津贴",
                                        "本期含 \(PayEngine.formatMoney(otAndDiffTotal, symbol: summary.currencySymbol)) 加班費與津貼"
                                    )
                                    : L10n.t("Detailed OT & Differentials", "完整加班费与夜班津贴精算", "完整加班費試算與夜班津貼")
                            )
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .foregroundStyle(ShiftTheme.overtimeAmber)

                            Text(
                                L10n.t(
                                    "Est. Net Take-Home: \(PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol))",
                                    "预估税后净到手：\(PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol))",
                                    "預估稅後實領：\(PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol))"
                                )
                            )
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(ShiftTheme.shiftMint)
                        }
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ShiftTheme.overtimeAmber)
                            .padding(8)
                            .background(ShiftTheme.overtimeAmber.opacity(0.16))
                            .clipShape(Circle())
                    }

                    // Blurred granular 1.5x/2.0x/Diff/Tax lines behind crisp inline CTA
                    ZStack {
                        VStack(spacing: 5) {
                            payLine(L10n.t("Overtime 1.5x", "1.5倍加班费", "1.5倍加班費"), PayEngine.formatMoney(summary.totalOvertimePay, symbol: summary.currencySymbol), ShiftTheme.overtimeAmber)
                            payLine(L10n.t("Double-Time 2.0x & Differentials", "2.0倍与夜班津贴", "2.0倍與夜班津貼"), PayEngine.formatMoney(PayEngine.roundCents(summary.totalDoubleTimePay + summary.totalDifferentialPay), symbol: summary.currencySymbol), ShiftTheme.nightViolet)
                            payLine(L10n.t("Tax Withholding & Net Pay", "税费扣除与实发", "稅金扣繳與實領"), PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol), ShiftTheme.shiftMint)
                        }
                        .blur(radius: 5.5)
                        .allowsHitTesting(false)

                        Button {
                            let msg = otAndDiffTotal > 0
                                ? L10n.t(
                                    "You've earned \(PayEngine.formatMoney(otAndDiffTotal, symbol: summary.currencySymbol)) in OT & differentials this period. Unlock Pro to audit every 1.5x, 2.0x, differential & net take-home dollar.",
                                    "您本期已产生 \(PayEngine.formatMoney(otAndDiffTotal, symbol: summary.currencySymbol)) 加班与夜班津贴。解锁 Pro 查看逐项 1.5x/2.0x 与税后实发明细。",
                                    "您本期已有 \(PayEngine.formatMoney(otAndDiffTotal, symbol: summary.currencySymbol)) 加班費與津貼。解鎖 Pro 逐項核對 1.5x/2.0x、夜班津貼與稅後實領。"
                                )
                                : L10n.t(
                                    "Unlock full 1.5x / 2.0x overtime, shift differentials, and net take-home pay breakdown.",
                                    "解锁完整 1.5x / 2.0x 加班倍率、夜班津贴与税后到手精算明细。",
                                    "解鎖完整 1.5x / 2.0x 加班費試算、夜班津貼與稅後實領明細。"
                                )
                            onOpenPaywall(msg, nil, nil)
                        } label: {
                            Label(
                                L10n.t("Unlock Detailed OT & Net Breakdown", "解锁完整加班、津贴与税后明细", "解鎖完整加班費與實領明細"),
                                systemImage: "sparkles"
                            )
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: ShiftTheme.cobalt.opacity(0.28), radius: 6, y: 2)
                        }
                    }
                }
                .padding(11)
                .background(ShiftTheme.cardElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ShiftTheme.overtimeAmber.opacity(0.35), lineWidth: 1)
                )
            }
        }
        .shiftCard(padding: 16, cornerRadius: 16)
    }

    private func payLine(_ left: String, _ right: String, _ color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(left)
                .font(bold ? .subheadline.weight(.bold) : .caption.weight(.medium))
                .foregroundStyle(bold ? ShiftTheme.ink : ShiftTheme.muted)
            Spacer()
            Text(right)
                .font((bold ? Font.subheadline.weight(.heavy) : Font.subheadline.weight(.semibold)).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var exportActionDeck: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    handlePDFShare()
                } label: {
                    Label(L10n.t("Share PDF Timesheet", "导出 / 分享 PDF", "匯出 / 分享 PDF"), systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ShiftTheme.cobalt)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    handlePrintPDF()
                } label: {
                    Label(L10n.t("Print", "打印", "列印"), systemImage: "printer.fill")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(ShiftTheme.card)
                        .foregroundStyle(ShiftTheme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ShiftTheme.border, lineWidth: 1))
                }
            }

            Button {
                handleCSVExport()
            } label: {
                HStack {
                    Label(L10n.t("Export Payroll CSV Spreadsheet", "导出 CSV 考勤算薪明细表", "匯出 CSV 薪資明細表"), systemImage: "tablecells.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if !store.isPro {
                        Text("PRO")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ShiftTheme.overtimeAmber)
                            .foregroundStyle(ShiftTheme.midnightIndigo)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(ShiftTheme.card)
                .foregroundStyle(ShiftTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ShiftTheme.border, lineWidth: 1))
            }

            if !store.isPro {
                if store.remainingFreePDFExports > 0 {
                    Text(
                        L10n.t(
                            "Free Plan: \(store.remainingFreePDFExports) of \(StoreManager.freeLifetimePDFExportLimit) lifetime free PDF export remaining · Zero ads forever.",
                            "免费版：剩余 \(store.remainingFreePDFExports)/\(StoreManager.freeLifetimePDFExportLimit) 次终身免费 PDF 导出体验 · 永久零广告。",
                            "免費版：剩餘 \(store.remainingFreePDFExports)/\(StoreManager.freeLifetimePDFExportLimit) 次終身免費 PDF 匯出體驗 · 永久零廣告。"
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(ShiftTheme.muted)
                    .multilineTextAlignment(.center)
                } else {
                    Text(
                        L10n.t(
                            "Free PDF sample used (1/1). Unlock FlatShift Pro for unlimited clean PDF & CSV exports.",
                            "免费 PDF 体验次数已用完（1/1）。解锁 FlatShift Pro 即可无限导出高清无水印 PDF 与 CSV。",
                            "免費 PDF 體驗次數已用完（1/1）。解鎖 FlatShift Pro 即可無限匯出高清無浮水印 PDF 與 CSV。"
                        )
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ShiftTheme.overtimeAmber)
                    .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func handlePDFShare() {
        if !store.canExportFreePDF {
            let price = store.displayPrice(for: FlatShiftProductID.lifetime)
            onOpenPaywall(
                L10n.t(
                    "You've used your 1 free PDF sample export. Unlock FlatShift Pro (7-day free trial or \(price) lifetime) for unlimited clean PDFs & CSVs.",
                    "您已使用 1 次免费 PDF 导出体验。升级 FlatShift Pro（含 7 天免费试用或 \(price) 永久买断）即可无限导出。",
                    "您已使用 1 次免費 PDF 匯出體驗。升級 FlatShift Pro（含 7 天免費試用或 \(price) 永久買斷）即可無限匯出。"
                ),
                nil,
                nil
            )
            return
        }
        exportPDFNow()
    }

    private func exportPDFNow() {
        let filename = "FlatShift_Timesheet_\(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try livePDFData.write(to: url, options: .atomic)
            store.recordPDFExport()
            shareFileURL = url
            showShareSheet = true
        } catch {
            statusBanner = L10n.t("Failed preparing PDF file.", "生成 PDF 文件失败。", "產生 PDF 檔案失敗。")
        }
    }

    private func handlePrintPDF() {
        if !store.canExportFreePDF {
            let price = store.displayPrice(for: FlatShiftProductID.lifetime)
            onOpenPaywall(
                L10n.t(
                    "Your 1 free PDF sample has been used. Unlock FlatShift Pro (\(price) lifetime or 7-day free trial) for unlimited printing & PDF exports.",
                    "1 次免费 PDF 体验已用完。解锁 FlatShift Pro（\(price) 永久买断或 7 天免费试用）即可无限打印与导出。",
                    "1 次免費 PDF 體驗已用完。解鎖 FlatShift Pro（\(price) 永久買斷或 7 天免費試用）即可無限列印與匯出。"
                ),
                nil,
                nil
            )
            return
        }
        guard UIPrintInteractionController.canPrint(livePDFData) else {
            exportPDFNow()
            return
        }
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "FlatShift Timesheet"
        controller.printInfo = info
        controller.printingItem = livePDFData
        controller.present(animated: true) { _, completed, _ in
            if completed {
                store.recordPDFExport()
                reviewManager.recordPDFExported()
            }
        }
    }

    private func handleCSVExport() {
        if !store.isPro {
            FunnelMetrics.shared.record(.csvExportAttempted)
            let price = store.displayPrice(for: FlatShiftProductID.lifetime)
            onOpenPaywall(
                L10n.t(
                    "CSV payroll spreadsheet export is included in FlatShift Pro (\(price) one-time or 7-day free trial).",
                    "CSV 考勤算薪表导出属于 FlatShift Pro 权益（支持 \(price) 永久买断或 7 天免费试用）。",
                    "CSV 薪資明細表匯出屬於 FlatShift Pro 權益（支援 \(price) 永久買斷或 7 天免費試用）。"
                ),
                store.canExportFreePDF ? L10n.t("Use My 1 Free PDF Sample Instead", "改用我的 1 次免费 PDF 体验", "改用我的 1 次免費 PDF 體驗") : nil,
                store.canExportFreePDF ? { exportPDFNow() } : nil
            )
            return
        }
        let csv = CSVTimesheetExporter.generateCSV(summary: summary, use24HourTime: shiftStore.preferences.use24HourTime)
        let filename = "FlatShift_Payroll_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            shareFileURL = url
            showShareSheet = true
        } catch {
            statusBanner = L10n.t("Failed creating CSV export.", "生成 CSV 文件失败。", "產生 CSV 檔案失敗。")
        }
    }
}

struct PDFKitTimesheetView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
