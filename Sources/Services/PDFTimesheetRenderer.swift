import Foundation
import UIKit

enum PDFTimesheetRenderer {
    static func renderPDFData(
        summary: PayPeriodSummary,
        jobTitle: String,
        employeeName: String,
        use24HourTime: Bool,
        includeBrandingFooter: Bool
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter 8.5 x 11 in
        let margin: CGFloat = 36
        let contentW = pageRect.width - margin * 2

        let indigo = UIColor(red: 19/255, green: 27/255, blue: 46/255, alpha: 1)
        let cobalt = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1)
        let mint = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1)
        let amber = UIColor(red: 217/255, green: 119/255, blue: 6/255, alpha: 1)
        let darkInk = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
        let mutedInk = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
        let zebraBg = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        let borderCol = UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "FlatShift Timesheet - \(jobTitle)",
            kCGPDFContextCreator as String: "FlatShift",
        ]

        let periodDF = DateFormatter()
        periodDF.locale = L10n.locale
        periodDF.dateFormat = L10n.t("MMM d, yyyy", "yyyy年M月d日")

        let rowDF = DateFormatter()
        rowDF.locale = L10n.locale
        rowDF.dateFormat = L10n.t("EEE, MMM d", "M月d日 EEE")

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { ctx in
            var pageNumber = 1

            func beginNewPage() {
                ctx.beginPage()
                UIColor.white.setFill()
                ctx.fill(pageRect)
            }

            func drawFooter(page: Int) {
                let fy = pageRect.height - 28
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: fy - 6))
                line.addLine(to: CGPoint(x: pageRect.width - margin, y: fy - 6))
                borderCol.setStroke()
                line.lineWidth = 0.7
                line.stroke()

                let left = includeBrandingFooter
                    ? L10n.t("Generated offline with FlatShift · 100% Local Paycheck Verification", "由 FlatShift 本地离线生成 · 零广告零云端上传")
                    : "\(jobTitle) · \(periodDF.string(from: summary.startDate)) – \(periodDF.string(from: summary.endDate))"
                drawText(left, in: CGRect(x: margin, y: fy, width: contentW * 0.74, height: 14), font: .systemFont(ofSize: 8.5), color: mutedInk)
                drawText(L10n.t("Page \(page)", "第 \(page) 页"), in: CGRect(x: margin + contentW * 0.74, y: fy, width: contentW * 0.26, height: 14), font: .systemFont(ofSize: 8.5), color: mutedInk, alignment: .right)
            }

            beginNewPage()

            // Top Midnight Indigo Header
            let headerH: CGFloat = 96
            indigo.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: headerH))
            cobalt.setFill()
            ctx.fill(CGRect(x: 0, y: headerH - 4, width: pageRect.width, height: 4))

            drawText(
                L10n.t("TIMESHEET & PAYCHECK VERIFICATION", "工时排班与工资核对单"),
                in: CGRect(x: margin, y: 20, width: contentW * 0.65, height: 22),
                font: .systemFont(ofSize: 16, weight: .heavy),
                color: .white
            )
            let subtitle = employeeName.isEmpty ? jobTitle : "\(employeeName)  ·  \(jobTitle)"
            drawText(
                subtitle,
                in: CGRect(x: margin, y: 46, width: contentW * 0.65, height: 18),
                font: .systemFont(ofSize: 11, weight: .semibold),
                color: UIColor(white: 0.86, alpha: 1)
            )
            drawText(
                L10n.t("Pay Period: ", "计薪周期：") + "\(periodDF.string(from: summary.startDate)) – \(periodDF.string(from: summary.endDate))",
                in: CGRect(x: margin, y: 66, width: contentW * 0.65, height: 16),
                font: .systemFont(ofSize: 9.5, weight: .medium),
                color: UIColor(white: 0.72, alpha: 1)
            )

            // Right header Net Pay highlight pill
            let pillRect = CGRect(x: pageRect.width - margin - 164, y: 20, width: 164, height: 56)
            UIColor.white.withAlphaComponent(0.10).setFill()
            UIBezierPath(roundedRect: pillRect, cornerRadius: 10).fill()
            drawText(
                L10n.t("EST. NET TAKE-HOME", "预估税后到手"),
                in: CGRect(x: pillRect.minX + 12, y: pillRect.minY + 8, width: pillRect.width - 24, height: 14),
                font: .systemFont(ofSize: 8.5, weight: .bold),
                color: mint,
                alignment: .right
            )
            drawText(
                PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol),
                in: CGRect(x: pillRect.minX + 12, y: pillRect.minY + 24, width: pillRect.width - 24, height: 24),
                font: .monospacedDigitSystemFont(ofSize: 18, weight: .heavy),
                color: .white,
                alignment: .right
            )

            var y: CGFloat = headerH + 18

            // 4 KPI Summary Cards
            let kpiGap: CGFloat = 10
            let kpiW = (contentW - kpiGap * 3) / 4
            let kpiH: CGFloat = 56
            let kpis: [(String, String, String, UIColor)] = [
                (
                    L10n.t("TOTAL HOURS", "总计工时"),
                    PayEngine.formatHoursDecimal(summary.totalHours) + " h",
                    L10n.t("Reg \(PayEngine.formatHoursDecimal(summary.totalRegularHours)) · OT \(PayEngine.formatHoursDecimal(summary.totalOTCombinedHours))", "常\(PayEngine.formatHoursDecimal(summary.totalRegularHours)) · 加\(PayEngine.formatHoursDecimal(summary.totalOTCombinedHours))"),
                    cobalt
                ),
                (
                    L10n.t("GROSS PAY", "税前应发"),
                    PayEngine.formatMoney(summary.totalGrossPay, symbol: summary.currencySymbol),
                    L10n.t("\(summary.totalShiftsWorked) shifts worked", "共出勤 \(summary.totalShiftsWorked) 班"),
                    darkInk
                ),
                (
                    L10n.t("OT & DIFFERENTIALS", "加班与津贴"),
                    PayEngine.formatMoney(PayEngine.roundCents(summary.totalOTCombinedPay + summary.totalDifferentialPay), symbol: summary.currencySymbol),
                    L10n.t("Diff \(PayEngine.formatMoney(summary.totalDifferentialPay, symbol: summary.currencySymbol))", "津贴 \(PayEngine.formatMoney(summary.totalDifferentialPay, symbol: summary.currencySymbol))"),
                    amber
                ),
                (
                    L10n.t("EST. WITHHOLDING", "预估扣税社保"),
                    "-" + PayEngine.formatMoney(summary.estimatedTax, symbol: summary.currencySymbol),
                    String(format: "%.1f%% est.", summary.effectiveTaxPercent),
                    mutedInk
                ),
            ]

            for (idx, item) in kpis.enumerated() {
                let x = margin + CGFloat(idx) * (kpiW + kpiGap)
                let box = CGRect(x: x, y: y, width: kpiW, height: kpiH)
                zebraBg.setFill()
                let path = UIBezierPath(roundedRect: box, cornerRadius: 8)
                path.fill()
                borderCol.setStroke()
                path.lineWidth = 0.8
                path.stroke()

                drawText(item.0, in: CGRect(x: x + 8, y: y + 7, width: kpiW - 16, height: 11), font: .systemFont(ofSize: 7.5, weight: .bold), color: mutedInk)
                drawText(item.1, in: CGRect(x: x + 8, y: y + 20, width: kpiW - 16, height: 18), font: .monospacedDigitSystemFont(ofSize: 13.5, weight: .heavy), color: item.3)
                drawText(item.2, in: CGRect(x: x + 8, y: y + 40, width: kpiW - 16, height: 12), font: .systemFont(ofSize: 8), color: mutedInk)
            }

            y += kpiH + 18

            // Table Columns
            let colDateW: CGFloat = 118
            let colTimeW: CGFloat = 96
            let colBreakW: CGFloat = 46
            let colRegW: CGFloat = 52
            let colOTW: CGFloat = 52
            let colDiffW: CGFloat = 76
            let colPayW: CGFloat = contentW - (colDateW + colTimeW + colBreakW + colRegW + colOTW + colDiffW)

            func drawTableHeader(at topY: CGFloat) -> CGFloat {
                let h: CGFloat = 24
                indigo.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin, y: topY, width: contentW, height: h), cornerRadius: 5).fill()
                let hf = UIFont.systemFont(ofSize: 8.5, weight: .bold)
                var cx = margin + 6
                drawText(L10n.t("DATE / SHIFT", "日期 / 班次"), in: CGRect(x: cx, y: topY + 6, width: colDateW - 6, height: 12), font: hf, color: .white)
                cx += colDateW - 6
                drawText(L10n.t("IN – OUT", "上下班时间"), in: CGRect(x: cx, y: topY + 6, width: colTimeW, height: 12), font: hf, color: .white)
                cx += colTimeW
                drawText(L10n.t("BREAK", "休息"), in: CGRect(x: cx, y: topY + 6, width: colBreakW, height: 12), font: hf, color: .white, alignment: .right)
                cx += colBreakW
                drawText(L10n.t("REG", "正常h"), in: CGRect(x: cx, y: topY + 6, width: colRegW, height: 12), font: hf, color: .white, alignment: .right)
                cx += colRegW
                drawText(L10n.t("OT", "加班h"), in: CGRect(x: cx, y: topY + 6, width: colOTW, height: 12), font: hf, color: .white, alignment: .right)
                cx += colOTW
                drawText(L10n.t("DIFF", "津贴"), in: CGRect(x: cx, y: topY + 6, width: colDiffW, height: 12), font: hf, color: .white, alignment: .right)
                cx += colDiffW
                drawText(L10n.t("LINE PAY", "应发小计"), in: CGRect(x: cx, y: topY + 6, width: colPayW - 6, height: 12), font: hf, color: .white, alignment: .right)
                return topY + h + 4
            }

            y = drawTableHeader(at: y)

            let payableRows = summary.breakdowns.filter { $0.shift.shiftType.isPayable }
            let rowFont = UIFont.systemFont(ofSize: 9, weight: .medium)
            let monoFont = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)

            if payableRows.isEmpty {
                drawText(
                    L10n.t("No worked shifts recorded in this pay period.", "当前计薪周期暂无出勤排班记录。"),
                    in: CGRect(x: margin, y: y + 14, width: contentW, height: 20),
                    font: .systemFont(ofSize: 10),
                    color: mutedInk,
                    alignment: .center
                )
                y += 46
            } else {
                for (index, item) in payableRows.enumerated() {
                    let rowH: CGFloat = 28
                    if y + rowH > pageRect.height - 135 {
                        drawFooter(page: pageNumber)
                        pageNumber += 1
                        beginNewPage()
                        y = 36
                        y = drawTableHeader(at: y)
                    }

                    if index % 2 == 1 {
                        zebraBg.setFill()
                        ctx.fill(CGRect(x: margin, y: y, width: contentW, height: rowH))
                    }

                    let dateStr = rowDF.string(from: item.shift.startDate)
                    let badgeStr = "[\(item.shift.shiftType.shortBadge)]"
                    let timeStr = "\(PayEngine.formatTime(item.shift.startDate, use24Hour: use24HourTime))–\(PayEngine.formatTime(item.shift.endDate, use24Hour: use24HourTime))"
                    let breakStr = item.shift.unpaidBreakMinutes > 0 ? "\(item.shift.unpaidBreakMinutes)m" : "—"
                    let regStr = PayEngine.formatHoursDecimal(item.regularHours)
                    let otStr = item.totalOTHours > 0 ? PayEngine.formatHoursDecimal(item.totalOTHours) : "—"
                    let diffStr = item.differentialPay > 0 ? "+" + PayEngine.formatMoney(item.differentialPay, symbol: item.job.currencySymbol) : "—"
                    let linePayStr = PayEngine.formatMoney(item.grossPay, symbol: item.job.currencySymbol)

                    var cx = margin + 6
                    drawText("\(dateStr) \(badgeStr)", in: CGRect(x: cx, y: y + 4, width: colDateW - 6, height: 12), font: .systemFont(ofSize: 8.8, weight: .semibold), color: darkInk)
                    drawText(item.job.name, in: CGRect(x: cx, y: y + 16, width: colDateW - 6, height: 10), font: .systemFont(ofSize: 7.4), color: mutedInk)
                    cx += colDateW - 6
                    drawText(timeStr, in: CGRect(x: cx, y: y + 8, width: colTimeW, height: 12), font: rowFont, color: darkInk)
                    cx += colTimeW
                    drawText(breakStr, in: CGRect(x: cx, y: y + 8, width: colBreakW, height: 12), font: monoFont, color: mutedInk, alignment: .right)
                    cx += colBreakW
                    drawText(regStr, in: CGRect(x: cx, y: y + 8, width: colRegW, height: 12), font: monoFont, color: darkInk, alignment: .right)
                    cx += colRegW
                    drawText(otStr, in: CGRect(x: cx, y: y + 8, width: colOTW, height: 12), font: monoFont, color: item.totalOTHours > 0 ? amber : mutedInk, alignment: .right)
                    cx += colOTW
                    drawText(diffStr, in: CGRect(x: cx, y: y + 8, width: colDiffW, height: 12), font: monoFont, color: item.differentialPay > 0 ? cobalt : mutedInk, alignment: .right)
                    cx += colDiffW
                    drawText(linePayStr, in: CGRect(x: cx, y: y + 8, width: colPayW - 6, height: 12), font: .monospacedDigitSystemFont(ofSize: 9.2, weight: .bold), color: darkInk, alignment: .right)

                    let sep = UIBezierPath()
                    sep.move(to: CGPoint(x: margin, y: y + rowH))
                    sep.addLine(to: CGPoint(x: pageRect.width - margin, y: y + rowH))
                    borderCol.setStroke()
                    sep.lineWidth = 0.5
                    sep.stroke()

                    y += rowH
                }
            }

            // Bottom Reconciliation Box
            if y + 130 > pageRect.height - 40 {
                drawFooter(page: pageNumber)
                pageNumber += 1
                beginNewPage()
                y = 40
            }

            y += 16
            let boxW: CGFloat = 256
            let boxX = pageRect.width - margin - boxW
            let boxH: CGFloat = 114
            zebraBg.setFill()
            let sumRect = CGRect(x: boxX, y: y, width: boxW, height: boxH)
            let sumPath = UIBezierPath(roundedRect: sumRect, cornerRadius: 10)
            sumPath.fill()
            borderCol.setStroke()
            sumPath.lineWidth = 0.8
            sumPath.stroke()

            let breakdownRows: [(String, String, UIColor, Bool)] = [
                (L10n.t("Regular Pay (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)", "正常工时薪资 (\(PayEngine.formatHoursDecimal(summary.totalRegularHours))h)"), PayEngine.formatMoney(summary.totalRegularPay, symbol: summary.currencySymbol), darkInk, false),
                (L10n.t("Overtime & DT (\(PayEngine.formatHoursDecimal(summary.totalOTCombinedHours))h)", "加班与双倍薪资 (\(PayEngine.formatHoursDecimal(summary.totalOTCombinedHours))h)"), PayEngine.formatMoney(summary.totalOTCombinedPay, symbol: summary.currencySymbol), amber, false),
                (L10n.t("Shift Differentials", "夜班 / 周末津贴"), PayEngine.formatMoney(summary.totalDifferentialPay, symbol: summary.currencySymbol), cobalt, false),
                (L10n.t("Gross Pay", "税前应发总额"), PayEngine.formatMoney(summary.totalGrossPay, symbol: summary.currencySymbol), darkInk, true),
                (L10n.t("Est. Tax Withholding", "预估税费扣除"), "-" + PayEngine.formatMoney(summary.estimatedTax, symbol: summary.currencySymbol), mutedInk, false),
                (L10n.t("Est. Net Take-Home Pay", "预估税后净到手"), PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol), mint, true),
            ]

            var ry = y + 8
            for (label, val, col, bold) in breakdownRows {
                let lf = UIFont.systemFont(ofSize: bold ? 9.5 : 8.8, weight: bold ? .bold : .medium)
                let vf = UIFont.monospacedDigitSystemFont(ofSize: bold ? 10 : 9, weight: bold ? .heavy : .semibold)
                drawText(label, in: CGRect(x: boxX + 12, y: ry, width: 145, height: 14), font: lf, color: bold ? darkInk : mutedInk)
                drawText(val, in: CGRect(x: boxX + 158, y: ry, width: boxW - 170, height: 14), font: vf, color: col, alignment: .right)
                ry += 16.5
            }

            // Left Approval / Verification Sign-off Lines
            let sigY = y + 26
            drawText(L10n.t("PAYCHECK VERIFICATION SIGN-OFF", "考勤与薪资核对签字"), in: CGRect(x: margin, y: y + 4, width: 230, height: 14), font: .systemFont(ofSize: 8.5, weight: .bold), color: mutedInk)
            for (offset, caption) in [(CGFloat(30), L10n.t("Employee Signature / Date", "员工确认签字 / 日期")), (CGFloat(76), L10n.t("Supervisor Approval / Date", "主管核验签字 / 日期"))] {
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: sigY + offset))
                line.addLine(to: CGPoint(x: margin + 225, y: sigY + offset))
                borderCol.setStroke()
                line.lineWidth = 1.0
                line.stroke()
                drawText(caption, in: CGRect(x: margin, y: sigY + offset + 4, width: 225, height: 12), font: .systemFont(ofSize: 8), color: mutedInk)
            }

            drawFooter(page: pageNumber)
        }
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}

enum CSVTimesheetExporter {
    static func generateCSV(summary: PayPeriodSummary, use24HourTime: Bool) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        var rows: [String] = [
            "Date,Job,ShiftType,ClockIn,ClockOut,BreakMin,RegularHours,OTHours,DoubleTimeHours,HourlyRate,RegularPay,OTPay,DoubleTimePay,DifferentialPay,GrossPay,EstTax,EstNetPay,Notes"
        ]

        for b in summary.breakdowns where b.shift.shiftType.isPayable {
            let rate = b.shift.customHourlyRate ?? b.job.hourlyRate
            let fields: [String] = [
                df.string(from: b.shift.startDate),
                b.job.name,
                b.shift.shiftType.rawValue.uppercased(),
                PayEngine.formatTime(b.shift.startDate, use24Hour: use24HourTime),
                PayEngine.formatTime(b.shift.endDate, use24Hour: use24HourTime),
                String(b.shift.unpaidBreakMinutes),
                PayEngine.formatHoursDecimal(b.regularHours),
                PayEngine.formatHoursDecimal(b.overtimeHours),
                PayEngine.formatHoursDecimal(b.doubleTimeHours),
                String(format: "%.2f", rate),
                String(format: "%.2f", b.regularPay),
                String(format: "%.2f", b.overtimePay),
                String(format: "%.2f", b.doubleTimePay),
                String(format: "%.2f", b.differentialPay),
                String(format: "%.2f", b.grossPay),
                String(format: "%.2f", b.estimatedTax),
                String(format: "%.2f", b.estimatedNetPay),
                b.shift.notes,
            ]
            rows.append(fields.map(escapeCSV).joined(separator: ","))
        }

        // Totals row
        let totals: [String] = [
            "TOTAL",
            "",
            "",
            "",
            "",
            "",
            PayEngine.formatHoursDecimal(summary.totalRegularHours),
            PayEngine.formatHoursDecimal(summary.totalOvertimeHours),
            PayEngine.formatHoursDecimal(summary.totalDoubleTimeHours),
            "",
            String(format: "%.2f", summary.totalRegularPay),
            String(format: "%.2f", summary.totalOvertimePay),
            String(format: "%.2f", summary.totalDoubleTimePay),
            String(format: "%.2f", summary.totalDifferentialPay),
            String(format: "%.2f", summary.totalGrossPay),
            String(format: "%.2f", summary.estimatedTax),
            String(format: "%.2f", summary.estimatedNetPay),
            "",
        ]
        rows.append(totals.map(escapeCSV).joined(separator: ","))
        return rows.joined(separator: "\n") + "\n"
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
