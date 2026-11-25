import Foundation
import UIKit

/// Renders a crisp, high-contrast 4:5 PNG monthly shift schedule grid ready to text to family & coworkers.
enum ScheduleImageRenderer {
    static let canvasSize = CGSize(width: 1080, height: 1350)

    static func renderMonthlyScheduleImage(
        monthDate: Date,
        shifts: [ShiftEntry],
        jobs: [JobProfile],
        employeeName: String,
        use24HourTime: Bool = true,
        includeBrandingBadge: Bool = true,
        darkTheme: Bool = false,
        calendar: Calendar = .current
    ) -> UIImage {
        var cal = calendar
        cal.firstWeekday = 2 // Monday start

        let monthComps = cal.dateComponents([.year, .month], from: monthDate)
        let monthStart = cal.date(from: monthComps) ?? monthDate
        let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let monthEnd = cal.date(byAdding: .second, value: -1, to: nextMonth) ?? monthStart

        let summary = PayEngine.summarize(
            shifts: shifts,
            jobs: jobs,
            periodStart: monthStart,
            periodEnd: monthEnd,
            calendar: cal
        )

        let byDay: [Date: [ShiftPayBreakdown]] = Dictionary(grouping: summary.breakdowns) { b in
            cal.startOfDay(for: b.shift.startDate)
        }

        let range = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leadingBlanks = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(d)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        let numRows = max(5, cells.count / 7)

        // Colors
        let indigo = UIColor(red: 19/255, green: 27/255, blue: 46/255, alpha: 1)
        let cobalt = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1)
        let mint = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1)
        let amber = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1)

        let bgColor = darkTheme
            ? UIColor(red: 11/255, green: 16/255, blue: 27/255, alpha: 1)
            : UIColor(red: 244/255, green: 246/255, blue: 250/255, alpha: 1)
        let cardBg = darkTheme
            ? UIColor(red: 19/255, green: 27/255, blue: 46/255, alpha: 1)
            : UIColor.white
        let cellBg = darkTheme
            ? UIColor(red: 26/255, green: 37/255, blue: 61/255, alpha: 1)
            : UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        let borderCol = darkTheme
            ? UIColor(red: 43/255, green: 57/255, blue: 86/255, alpha: 1)
            : UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1)
        let primaryInk = darkTheme
            ? UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
            : UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
        let mutedInk = darkTheme
            ? UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1)
            : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)

        let monthDF = DateFormatter()
        monthDF.locale = L10n.locale
        monthDF.dateFormat = L10n.t("MMMM yyyy", "yyyy年M月", "yyyy年M月")
        let monthTitle = monthDF.string(from: monthStart)

        let jobName: String = {
            if let primary = jobs.first?.name, !primary.isEmpty {
                if jobs.count > 1 {
                    return primary + " +\(jobs.count - 1)"
                }
                return primary
            }
            return L10n.t("Shift Schedule", "排班表", "排班更表")
        }()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            let bounds = CGRect(origin: .zero, size: canvasSize)
            bgColor.setFill()
            ctx.fill(bounds)

            // MARK: Top Header Banner
            let headerH: CGFloat = 196
            indigo.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: headerH))
            cobalt.setFill()
            ctx.fill(CGRect(x: 0, y: headerH - 6, width: bounds.width, height: 6))

            let margin: CGFloat = 44
            let contentW = bounds.width - margin * 2

            drawText(
                L10n.t("MONTHLY SHIFT SCHEDULE", "月度倒班排班表", "月度排班更表"),
                in: CGRect(x: margin, y: 34, width: contentW * 0.62, height: 24),
                font: .systemFont(ofSize: 18, weight: .bold),
                color: mint
            )

            drawText(
                monthTitle,
                in: CGRect(x: margin, y: 62, width: contentW * 0.62, height: 56),
                font: .systemFont(ofSize: 44, weight: .heavy),
                color: .white
            )

            let subLine = employeeName.isEmpty ? jobName : "\(employeeName)  ·  \(jobName)"
            drawText(
                subLine,
                in: CGRect(x: margin, y: 128, width: contentW * 0.62, height: 32),
                font: .systemFont(ofSize: 22, weight: .semibold),
                color: UIColor(white: 0.84, alpha: 1)
            )

            // Right KPI pills: Total Shifts & Total Hours
            let pillW: CGFloat = 166
            let pillH: CGFloat = 104
            let pillY: CGFloat = 44
            let hoursPillRect = CGRect(x: bounds.width - margin - pillW, y: pillY, width: pillW, height: pillH)
            let shiftsPillRect = CGRect(x: hoursPillRect.minX - 16 - pillW, y: pillY, width: pillW, height: pillH)

            drawHeaderPill(
                rect: shiftsPillRect,
                title: L10n.t("SHIFTS", "出勤班次", "當月更數"),
                value: "\(summary.totalShiftsWorked)",
                accent: .white
            )
            drawHeaderPill(
                rect: hoursPillRect,
                title: L10n.t("TOTAL HOURS", "总计工时", "總計工時"),
                value: PayEngine.formatHours(summary.totalHours),
                accent: amber
            )

            // MARK: Main Calendar Card Container
            let gridCardY: CGFloat = headerH + 28
            let footerReserve: CGFloat = 134
            let gridCardH = bounds.height - gridCardY - footerReserve
            let gridCardRect = CGRect(x: margin, y: gridCardY, width: contentW, height: gridCardH)

            let cardPath = UIBezierPath(roundedRect: gridCardRect, cornerRadius: 24)
            cardBg.setFill()
            cardPath.fill()
            borderCol.setStroke()
            cardPath.lineWidth = 2
            cardPath.stroke()

            let innerPad: CGFloat = 22
            let innerX = gridCardRect.minX + innerPad
            let innerW = gridCardRect.width - innerPad * 2
            let gap: CGFloat = 10
            let colW = (innerW - gap * 6) / 7

            // Weekday Header Row
            let weekdays: [String] = L10n.isChinese
                ? ["一", "二", "三", "四", "五", "六", "日"]
                : ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

            let weekdayY = gridCardRect.minY + 20
            for (idx, sym) in weekdays.enumerated() {
                let x = innerX + CGFloat(idx) * (colW + gap)
                drawText(
                    sym,
                    in: CGRect(x: x, y: weekdayY, width: colW, height: 24),
                    font: .systemFont(ofSize: 18, weight: .heavy),
                    color: (idx >= 5) ? cobalt : mutedInk,
                    alignment: .center
                )
            }

            // Day Cells Grid
            let cellsStartY = weekdayY + 34
            let cellsTotalH = gridCardRect.maxY - cellsStartY - 22
            let rowH = (cellsTotalH - gap * CGFloat(numRows - 1)) / CGFloat(numRows)

            for (idx, dateOpt) in cells.enumerated() {
                let row = idx / 7
                let col = idx % 7
                let x = innerX + CGFloat(col) * (colW + gap)
                let y = cellsStartY + CGFloat(row) * (rowH + gap)
                let cellRect = CGRect(x: x, y: y, width: colW, height: rowH)

                guard let date = dateOpt else { continue }
                let dayStart = cal.startOfDay(for: date)
                let dayItems = byDay[dayStart] ?? []
                let primary = dayItems.first(where: { $0.shift.shiftType.isPayable }) ?? dayItems.first

                let cellPath = UIBezierPath(roundedRect: cellRect, cornerRadius: 14)
                cellBg.setFill()
                cellPath.fill()
                borderCol.setStroke()
                cellPath.lineWidth = 1.2
                cellPath.stroke()

                // Day number
                let dayNum = cal.component(.day, from: date)
                drawText(
                    "\(dayNum)",
                    in: CGRect(x: cellRect.minX + 10, y: cellRect.minY + 8, width: 44, height: 26),
                    font: .monospacedDigitSystemFont(ofSize: 22, weight: .heavy),
                    color: primaryInk
                )

                if let item = primary {
                    let pillColor = uiColor(for: item.shift.shiftType)
                    let badgeRect = CGRect(
                        x: cellRect.minX + 8,
                        y: cellRect.minY + 42,
                        width: cellRect.width - 16,
                        height: 36
                    )
                    pillColor.setFill()
                    UIBezierPath(roundedRect: badgeRect, cornerRadius: 9).fill()

                    drawText(
                        item.shift.shiftType.shortBadge,
                        in: CGRect(x: badgeRect.minX + 4, y: badgeRect.minY + 7, width: badgeRect.width - 8, height: 22),
                        font: .systemFont(ofSize: 17, weight: .black),
                        color: .white,
                        alignment: .center
                    )

                    if item.shift.shiftType.isPayable {
                        let startStr = PayEngine.formatTime(item.shift.startDate, use24Hour: use24HourTime)
                        let hrsStr = PayEngine.formatHours(item.totalHours)
                        let subLabel = rowH >= 135 ? "\(startStr) · \(hrsStr)" : hrsStr
                        drawText(
                            subLabel,
                            in: CGRect(x: cellRect.minX + 6, y: badgeRect.maxY + 8, width: cellRect.width - 12, height: 22),
                            font: .monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                            color: mutedInk,
                            alignment: .center
                        )
                    }
                }
            }

            // MARK: Legend Row
            let legendY = gridCardRect.maxY + 22
            let legendItems: [ShiftType] = [.day, .night, .swing, .overtime, .pto, .off]
            var lx = margin
            for st in legendItems {
                let dotRect = CGRect(x: lx, y: legendY + 6, width: 16, height: 16)
                uiColor(for: st).setFill()
                UIBezierPath(ovalIn: dotRect).fill()

                let label = st.shortBadge
                let font = UIFont.systemFont(ofSize: 18, weight: .bold)
                let size = (label as NSString).size(withAttributes: [.font: font])
                drawText(
                    label,
                    in: CGRect(x: lx + 22, y: legendY + 3, width: size.width + 8, height: 24),
                    font: font,
                    color: mutedInk
                )
                lx += 22 + size.width + 26
            }

            // MARK: Bottom Badge / Footer
            let footerY = bounds.height - 72
            if includeBrandingBadge {
                let badgeRect = CGRect(x: margin, y: footerY, width: contentW, height: 48)
                let badgeBg = darkTheme
                    ? UIColor.white.withAlphaComponent(0.08)
                    : UIColor(red: 19/255, green: 27/255, blue: 46/255, alpha: 0.06)
                badgeBg.setFill()
                UIBezierPath(roundedRect: badgeRect, cornerRadius: 14).fill()

                drawText(
                    L10n.t(
                        "Made with FlatShift • Zero-Ad Offline Shift Calendar",
                        "由 FlatShift 生成 • 零广告离线倒班日历",
                        "由 FlatShift 製作 • 零廣告離線排班更表"
                    ),
                    in: CGRect(x: badgeRect.minX + 16, y: badgeRect.minY + 13, width: badgeRect.width - 32, height: 24),
                    font: .systemFont(ofSize: 18, weight: .bold),
                    color: darkTheme ? UIColor(white: 0.85, alpha: 1) : indigo,
                    alignment: .center
                )
            } else {
                drawText(
                    "\(jobName)  ·  \(monthTitle)",
                    in: CGRect(x: margin, y: footerY + 12, width: contentW, height: 24),
                    font: .systemFont(ofSize: 17, weight: .semibold),
                    color: mutedInk,
                    alignment: .center
                )
            }
        }
    }

    static func renderMonthlySchedulePNG(
        monthDate: Date,
        shifts: [ShiftEntry],
        jobs: [JobProfile],
        employeeName: String,
        use24HourTime: Bool = true,
        includeBrandingBadge: Bool = true,
        darkTheme: Bool = false,
        calendar: Calendar = .current
    ) -> Data? {
        let image = renderMonthlyScheduleImage(
            monthDate: monthDate,
            shifts: shifts,
            jobs: jobs,
            employeeName: employeeName,
            use24HourTime: use24HourTime,
            includeBrandingBadge: includeBrandingBadge,
            darkTheme: darkTheme,
            calendar: calendar
        )
        return image.pngData()
    }

    private static func drawHeaderPill(rect: CGRect, title: String, value: String, accent: UIColor) {
        UIColor.white.withAlphaComponent(0.10).setFill()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 16)
        path.fill()
        UIColor.white.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 1.2
        path.stroke()

        drawText(
            title,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 14, width: rect.width - 28, height: 20),
            font: .systemFont(ofSize: 14, weight: .bold),
            color: UIColor(white: 0.72, alpha: 1),
            alignment: .center
        )
        drawText(
            value,
            in: CGRect(x: rect.minX + 10, y: rect.minY + 42, width: rect.width - 20, height: 46),
            font: .monospacedDigitSystemFont(ofSize: 34, weight: .heavy),
            color: accent,
            alignment: .center
        )
    }

    private static func uiColor(for type: ShiftType) -> UIColor {
        switch type {
        case .day: return UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 1)
        case .night: return UIColor(red: 124/255, green: 58/255, blue: 237/255, alpha: 1)
        case .swing: return UIColor(red: 13/255, green: 148/255, blue: 136/255, alpha: 1)
        case .overtime: return UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1)
        case .pto: return UIColor(red: 225/255, green: 29/255, blue: 72/255, alpha: 1)
        case .off: return UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
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
