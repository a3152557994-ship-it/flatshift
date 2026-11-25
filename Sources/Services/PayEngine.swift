import Foundation

struct ShiftPayBreakdown: Identifiable, Equatable {
    let shift: ShiftEntry
    let job: JobProfile
    let regularHours: Double
    let overtimeHours: Double
    let doubleTimeHours: Double
    let totalHours: Double
    let regularPay: Double
    let overtimePay: Double
    let doubleTimePay: Double
    let differentialPay: Double
    let grossPay: Double
    let estimatedTax: Double
    let estimatedNetPay: Double

    var id: UUID { shift.id }
    var totalOTHours: Double { overtimeHours + doubleTimeHours }
}

struct PayPeriodSummary: Equatable {
    let startDate: Date
    let endDate: Date
    let currencySymbol: String
    let breakdowns: [ShiftPayBreakdown]
    let totalShiftsWorked: Int
    let totalRegularHours: Double
    let totalOvertimeHours: Double
    let totalDoubleTimeHours: Double
    let totalHours: Double
    let totalRegularPay: Double
    let totalOvertimePay: Double
    let totalDoubleTimePay: Double
    let totalDifferentialPay: Double
    let totalGrossPay: Double
    let estimatedTax: Double
    let estimatedNetPay: Double

    var effectiveTaxPercent: Double {
        guard totalGrossPay > 0 else { return 0 }
        return PayEngine.roundCents((estimatedTax / totalGrossPay) * 100.0)
    }

    var totalOTCombinedHours: Double {
        totalOvertimeHours + totalDoubleTimeHours
    }

    var totalOTCombinedPay: Double {
        PayEngine.roundCents(totalOvertimePay + totalDoubleTimePay)
    }
}

enum PayEngine {
    /// Clean penny rounding with IEEE-754 half-cent epsilon protection so breakdowns ALWAYS sum to the exact cent.
    static func roundCents(_ value: Double) -> Double {
        let eps = value >= 0 ? 1e-9 : -1e-9
        return ((value * 100.0) + eps).rounded() / 100.0
    }

    static func formatMoney(_ amount: Double, symbol: String = "$") -> String {
        let rounded = roundCents(amount)
        let negative = rounded < 0
        let absVal = abs(rounded)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 2
        fmt.maximumFractionDigits = 2
        fmt.groupingSeparator = ","
        let num = fmt.string(from: NSNumber(value: absVal)) ?? String(format: "%.2f", absVal)
        return (negative ? "-" : "") + symbol + num
    }

    static func formatHours(_ hours: Double) -> String {
        let rounded = roundCents(hours)
        if abs(rounded.truncatingRemainder(dividingBy: 1)) < 0.005 {
            return String(format: "%.0fh", rounded)
        }
        if abs((rounded * 10).truncatingRemainder(dividingBy: 1)) < 0.05 {
            return String(format: "%.1fh", rounded)
        }
        return String(format: "%.2fh", rounded)
    }

    static func formatHoursDecimal(_ hours: Double) -> String {
        String(format: "%.2f", roundCents(hours))
    }

    static func formatTime(_ date: Date, use24Hour: Bool) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        return df.string(from: date)
    }

    static func isWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        let wd = calendar.component(.weekday, from: date)
        return wd == 1 || wd == 7
    }

    /// Compute date range for the pay period containing `referenceDate`, shifted by `offset` periods.
    static func payPeriodRange(
        cycle: PayPeriodCycle,
        referenceDate: Date = Date(),
        offset: Int = 0,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        var cal = calendar
        cal.firstWeekday = 2 // Monday start for shift rosters
        let today = cal.startOfDay(for: referenceDate)

        switch cycle {
        case .weekly:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            let weekStart = cal.date(from: comps) ?? today
            let start = cal.date(byAdding: .day, value: offset * 7, to: weekStart) ?? today
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            return (start, endOfDay(end, cal: cal))

        case .biweekly:
            // Anchor biweekly cycle cleanly to Monday of the previous week so current + last week are centered
            let anchor = cal.date(from: DateComponents(year: 2026, month: 1, day: 5)) ?? today // Monday
            let daysSinceAnchor = cal.dateComponents([.day], from: anchor, to: today).day ?? 0
            let periodIndex = Int(floor(Double(daysSinceAnchor) / 14.0)) + offset
            let start = cal.date(byAdding: .day, value: periodIndex * 14, to: anchor) ?? today
            let end = cal.date(byAdding: .day, value: 13, to: start) ?? start
            return (start, endOfDay(end, cal: cal))

        case .semimonthly:
            let day = cal.component(.day, from: today)
            let baseMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
            let currentHalfIndex = (day <= 15) ? 0 : 1
            let totalHalfSteps = currentHalfIndex + offset
            let monthDelta = Int(floor(Double(totalHalfSteps) / 2.0))
            let isSecondHalf = ((totalHalfSteps % 2) + 2) % 2 == 1
            let targetMonthStart = cal.date(byAdding: .month, value: monthDelta, to: baseMonthStart) ?? baseMonthStart
            if !isSecondHalf {
                let end = cal.date(byAdding: .day, value: 14, to: targetMonthStart) ?? targetMonthStart
                return (targetMonthStart, endOfDay(end, cal: cal))
            } else {
                let start = cal.date(byAdding: .day, value: 15, to: targetMonthStart) ?? targetMonthStart
                let nextMonth = cal.date(byAdding: .month, value: 1, to: targetMonthStart) ?? targetMonthStart
                let end = cal.date(byAdding: .day, value: -1, to: nextMonth) ?? start
                return (start, endOfDay(end, cal: cal))
            }

        case .monthly:
            let baseMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
            let start = cal.date(byAdding: .month, value: offset, to: baseMonthStart) ?? baseMonthStart
            let nextMonth = cal.date(byAdding: .month, value: 1, to: start) ?? start
            let end = cal.date(byAdding: .day, value: -1, to: nextMonth) ?? start
            return (start, endOfDay(end, cal: cal))
        }
    }

    private static func endOfDay(_ date: Date, cal: Calendar) -> Date {
        let start = cal.startOfDay(for: date)
        return cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    /// Evaluates shifts chronologically with Daily OT, Daily Double-Time, Weekly OT rollover (no double counting),
    /// Holiday multiplier, Night & Weekend Differentials, and Estimated Tax Withholding — exact to the cent.
    static func summarize(
        shifts: [ShiftEntry],
        jobs: [JobProfile],
        periodStart: Date,
        periodEnd: Date,
        filterJobId: UUID? = nil,
        defaultCurrency: String = "$",
        calendar: Calendar = .current
    ) -> PayPeriodSummary {
        var cal = calendar
        cal.firstWeekday = 2

        let jobMap = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
        let filtered = shifts
            .filter { shift in
                if let fid = filterJobId, shift.jobId != fid { return false }
                return shift.startDate >= periodStart && shift.startDate <= periodEnd
            }
            .sorted { $0.startDate < $1.startDate }

        // Track cumulative regular hours per (jobId, yearForWeekOfYear-weekOfYear)
        var weeklyRegularAccum: [String: Double] = [:]
        var breakdowns: [ShiftPayBreakdown] = []

        for shift in filtered {
            guard let job = jobMap[shift.jobId] else { continue }
            let totalH = shift.payableHours

            if !shift.shiftType.isPayable || totalH <= 0 {
                breakdowns.append(
                    ShiftPayBreakdown(
                        shift: shift,
                        job: job,
                        regularHours: 0,
                        overtimeHours: 0,
                        doubleTimeHours: 0,
                        totalHours: 0,
                        regularPay: 0,
                        overtimePay: 0,
                        doubleTimePay: 0,
                        differentialPay: 0,
                        grossPay: 0,
                        estimatedTax: 0,
                        estimatedNetPay: 0
                    )
                )
                continue
            }

            let baseRate = shift.customHourlyRate ?? job.hourlyRate
            var regH: Double = 0
            var ot15H: Double = 0
            var ot20H: Double = 0

            if shift.isHoliday && job.holidayMultiplier > 1.0 {
                // Holiday shift paid at holiday multiplier
                if job.holidayMultiplier >= 2.0 {
                    ot20H = totalH
                } else {
                    ot15H = totalH
                }
            } else if shift.shiftType == .overtime {
                // Dedicated overtime shift
                ot15H = totalH
            } else {
                // Daily Double-Time tier
                if job.dailyDoubleTimeThresholdHours > 0 && totalH > job.dailyDoubleTimeThresholdHours {
                    ot20H = totalH - job.dailyDoubleTimeThresholdHours
                }
                let underDT = totalH - ot20H
                // Daily Overtime tier
                if job.dailyOTThresholdHours > 0 && underDT > job.dailyOTThresholdHours {
                    ot15H = underDT - job.dailyOTThresholdHours
                    regH = job.dailyOTThresholdHours
                } else {
                    regH = underDT
                }

                // Weekly Overtime rollover on remaining regular hours (avoids double-counting daily OT)
                if job.weeklyOTThresholdHours > 0 && regH > 0 {
                    let yw = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: shift.startDate)
                    let key = "\(job.id.uuidString)-\(yw.yearForWeekOfYear ?? 0)-\(yw.weekOfYear ?? 0)"
                    let alreadyReg = weeklyRegularAccum[key, default: 0]
                    let remainingRegularRoom = max(0, job.weeklyOTThresholdHours - alreadyReg)
                    if regH > remainingRegularRoom {
                        let promotedToWeeklyOT = regH - remainingRegularRoom
                        regH = remainingRegularRoom
                        ot15H += promotedToWeeklyOT
                    }
                    weeklyRegularAccum[key] = alreadyReg + regH
                }
            }

            let effectiveOTMult: Double = {
                if shift.isHoliday && job.holidayMultiplier > 1.0 && job.holidayMultiplier < 2.0 {
                    return job.holidayMultiplier
                }
                return max(job.dailyOTMultiplier, job.weeklyOTMultiplier)
            }()
            let effectiveDTMult: Double = shift.isHoliday ? job.holidayMultiplier : job.dailyDoubleTimeMultiplier

            let diffRate = (shift.applyNightDiff ? job.nightDifferentialPerHour : 0)
                + (shift.applyWeekendDiff ? job.weekendDifferentialPerHour : 0)

            let regPay = roundCents(regH * baseRate)
            let otPay = roundCents(ot15H * baseRate * effectiveOTMult)
            let dtPay = roundCents(ot20H * baseRate * effectiveDTMult)
            let diffPay = roundCents(totalH * diffRate)
            let gross = roundCents(regPay + otPay + dtPay + diffPay)
            let tax = roundCents(gross * (max(0, job.estimatedTaxRatePercent) / 100.0))
            let net = roundCents(gross - tax)

            breakdowns.append(
                ShiftPayBreakdown(
                    shift: shift,
                    job: job,
                    regularHours: regH,
                    overtimeHours: ot15H,
                    doubleTimeHours: ot20H,
                    totalHours: totalH,
                    regularPay: regPay,
                    overtimePay: otPay,
                    doubleTimePay: dtPay,
                    differentialPay: diffPay,
                    grossPay: gross,
                    estimatedTax: tax,
                    estimatedNetPay: net
                )
            )
        }

        let workedCount = breakdowns.filter { $0.totalHours > 0 }.count
        let sumRegH = breakdowns.reduce(0) { $0 + $1.regularHours }
        let sumOTH = breakdowns.reduce(0) { $0 + $1.overtimeHours }
        let sumDTH = breakdowns.reduce(0) { $0 + $1.doubleTimeHours }
        let sumTotalH = breakdowns.reduce(0) { $0 + $1.totalHours }

        let sumRegPay = roundCents(breakdowns.reduce(0) { $0 + $1.regularPay })
        let sumOTPay = roundCents(breakdowns.reduce(0) { $0 + $1.overtimePay })
        let sumDTPay = roundCents(breakdowns.reduce(0) { $0 + $1.doubleTimePay })
        let sumDiffPay = roundCents(breakdowns.reduce(0) { $0 + $1.differentialPay })
        let sumGross = roundCents(sumRegPay + sumOTPay + sumDTPay + sumDiffPay)
        let sumTax = roundCents(breakdowns.reduce(0) { $0 + $1.estimatedTax })
        let sumNet = roundCents(sumGross - sumTax)

        let currency = filterJobId.flatMap { jobMap[$0]?.currencySymbol }
            ?? breakdowns.first?.job.currencySymbol
            ?? jobs.first?.currencySymbol
            ?? defaultCurrency

        return PayPeriodSummary(
            startDate: periodStart,
            endDate: periodEnd,
            currencySymbol: currency,
            breakdowns: breakdowns,
            totalShiftsWorked: workedCount,
            totalRegularHours: sumRegH,
            totalOvertimeHours: sumOTH,
            totalDoubleTimeHours: sumDTH,
            totalHours: sumTotalH,
            totalRegularPay: sumRegPay,
            totalOvertimePay: sumOTPay,
            totalDoubleTimePay: sumDTPay,
            totalDifferentialPay: sumDiffPay,
            totalGrossPay: sumGross,
            estimatedTax: sumTax,
            estimatedNetPay: sumNet
        )
    }

    /// Generate shift entries from a rotation pattern over N weeks.
    static func generateRotationShifts(
        pattern: RotationPattern,
        job: JobProfile,
        startDate: Date,
        weeks: Int,
        dayStartHour: Int = 7,
        nightStartHour: Int = 19,
        shiftDurationHours: Double? = nil,
        calendar: Calendar = .current
    ) -> [ShiftEntry] {
        let totalDays = max(1, weeks) * 7
        let cycle = pattern.cycle
        let durHours = shiftDurationHours ?? pattern.defaultHours
        let unpaidBreak = job.defaultUnpaidBreakMinutes
        let totalMinutesOnClock = Int(round(durHours * 60.0)) + unpaidBreak
        let anchorDay = calendar.startOfDay(for: startDate)

        var result: [ShiftEntry] = []
        for offset in 0..<totalDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: anchorDay) else { continue }
            let sType = cycle[offset % cycle.count]
            if sType == .off {
                let s = calendar.date(byAdding: .hour, value: 9, to: day) ?? day
                result.append(
                    ShiftEntry(
                        jobId: job.id,
                        shiftType: .off,
                        startDate: s,
                        endDate: s,
                        unpaidBreakMinutes: 0,
                        isHoliday: false,
                        applyNightDiff: false,
                        applyWeekendDiff: false,
                        notes: L10n.t("Scheduled Off", "排班休息")
                    )
                )
            } else {
                let startHour = (sType == .night) ? nightStartHour : dayStartHour
                let start = calendar.date(byAdding: .hour, value: startHour, to: day) ?? day
                let end = calendar.date(byAdding: .minute, value: totalMinutesOnClock, to: start) ?? start
                result.append(
                    ShiftEntry(
                        jobId: job.id,
                        shiftType: sType,
                        startDate: start,
                        endDate: end,
                        unpaidBreakMinutes: unpaidBreak,
                        isHoliday: false,
                        applyNightDiff: sType == .night,
                        applyWeekendDiff: isWeekend(start, calendar: calendar),
                        notes: pattern.title
                    )
                )
            }
        }
        return result
    }
}
