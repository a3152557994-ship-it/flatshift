import PDFKit
import SwiftUI
import UIKit

struct PaycheckTabView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager

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
            ? (shiftStore.jobs.first?.name ?? L10n.t("All Jobs", "全部工作"))
            : L10n.t("All Jobs Combined", "全部工作汇总")
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
        df.dateFormat = L10n.t("MMM d", "M月d日")
        return "\(df.string(from: periodRange.start)) – \(df.string(from: periodRange.end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // MARK: - Pay Period & Job Filter Controls
                    periodSelectorCard

                    // MARK: - Interactive Paycheck Reconciliation Card
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
                            Label(L10n.t("Live PDF Timesheet Preview", "实时矢量 PDF 工资核对单预览"), systemImage: "doc.richtext.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(ShiftTheme.ink)
                            Spacer()
                            Button {
                                showFullScreenPDF = true
                            } label: {
                                Label(L10n.t("Expand", "全屏查看"), systemImage: "arrow.up.left.and.arrow.down.right")
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
            .navigationTitle(L10n.t("Paycheck & Timesheet", "工资单与导出"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShareSheet) {
                if let url = shareFileURL {
                    ActivityShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showFullScreenPDF) {
                NavigationStack {
                    PDFKitTimesheetView(data: livePDFData)
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle(L10n.t("PDF Timesheet", "PDF 工资核对单"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10n.t("Done", "完成")) { showFullScreenPDF = false }
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
                    Text("\(shiftStore.preferences.payPeriodCycle.title) · \(summary.totalShiftsWorked) \(L10n.t("shifts", "班"))")
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
                        jobPill(title: L10n.t("All Jobs", "全部工作"), active: filterJobId == nil) { filterJobId = nil }
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
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("ESTIMATED NET TAKE-HOME", "预估税后到手"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ShiftTheme.shiftMint)
                    Text(PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol))
                        .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(ShiftTheme.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.t("TOTAL PAID HOURS", "计薪总工时"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ShiftTheme.muted)
                    Text(PayEngine.formatHoursDecimal(summary.totalHours) + " h")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(ShiftTheme.cobalt)
                }
            }

            Divider()

            payLine(
                L10n.t("Regular Pay (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)", "正常工时薪资 (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)"),
                PayEngine.formatMoney(summary.totalRegularPay, symbol: summary.currencySymbol),
                ShiftTheme.ink
            )
            payLine(
                L10n.t("Overtime & DT (\(PayEngine.formatHoursDecimal(summary.totalOTCombinedHours))h)", "加班与双倍薪资 (\(PayEngine.formatHoursDecimal(summary.totalOTCombinedHours))h)"),
                PayEngine.formatMoney(summary.totalOTCombinedPay, symbol: summary.currencySymbol),
                ShiftTheme.overtimeAmber
            )
            payLine(
                L10n.t("Night & Weekend Differentials", "夜班与周末津贴"),
                "+" + PayEngine.formatMoney(summary.totalDifferentialPay, symbol: summary.currencySymbol),
                ShiftTheme.nightViolet
            )

            Divider()

            payLine(
                L10n.t("Gross Pay", "税前应发总额"),
                PayEngine.formatMoney(summary.totalGrossPay, symbol: summary.currencySymbol),
                ShiftTheme.ink,
                bold: true
            )
            payLine(
                L10n.t("Est. Tax Withholding (\(String(format: "%.1f%%", summary.effectiveTaxPercent)))", "预估个税社保 (\(String(format: "%.1f%%", summary.effectiveTaxPercent)))"),
                "-" + PayEngine.formatMoney(summary.estimatedTax, symbol: summary.currencySymbol),
                ShiftTheme.muted
            )
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
                    Label(L10n.t("Share PDF Timesheet", "导出 / 分享 PDF"), systemImage: "square.and.arrow.up")
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
                    Label(L10n.t("Print", "打印"), systemImage: "printer.fill")
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
                    Label(L10n.t("Export Payroll CSV Spreadsheet", "导出 CSV 考勤算薪明细表"), systemImage: "tablecells.fill")
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
                Text(L10n.t(
                    "Free Plan: \(store.remainingFreeExportsThisMonth) of \(StoreManager.freeMonthlyExportLimit) PDF exports left this month · Zero ads forever.",
                    "免费版：本月剩余 \(store.remainingFreeExportsThisMonth)/\(StoreManager.freeMonthlyExportLimit) 次免费 PDF 导出 · 永久零广告。"
                ))
                .font(.caption2)
                .foregroundStyle(ShiftTheme.muted)
                .multilineTextAlignment(.center)
            }
        }
    }

    private func handlePDFShare() {
        if !store.canExportFreePDF {
            onOpenPaywall(
                L10n.t("You've used both free PDF exports this month. Unlock FlatShift Pro once ($9.99) for unlimited PDFs & CSVs forever.", "您本月 2 次免费 PDF 导出已用完。一次买断 FlatShift Pro 即可终身无限导出。"),
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
            if !store.isPro {
                store.recordPDFExport()
            }
            shareFileURL = url
            showShareSheet = true
        } catch {
            statusBanner = L10n.t("Failed preparing PDF file.", "生成 PDF 文件失败。")
        }
    }

    private func handlePrintPDF() {
        if !store.canExportFreePDF {
            onOpenPaywall(
                L10n.t("Monthly free export quota reached. Unlock Lifetime Pro for unlimited printing & PDF exports.", "本月免费导出额度已满，解锁永久买断版即可无限打印与导出。"),
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
            if completed && !store.isPro {
                store.recordPDFExport()
            }
        }
    }

    private func handleCSVExport() {
        if !store.isPro {
            onOpenPaywall(
                L10n.t("CSV payroll spreadsheet export is included in FlatShift Pro ($9.99 one-time).", "CSV 考勤算薪表导出属于 FlatShift Pro 权益（支持一次买断终身用）。"),
                store.canExportFreePDF ? L10n.t("Export Free PDF Instead", "改用免费 PDF 导出") : nil,
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
            statusBanner = L10n.t("Failed creating CSV export.", "生成 CSV 文件失败。")
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
