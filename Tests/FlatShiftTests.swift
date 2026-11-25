import PDFKit
import XCTest
@testable import FlatShift

@MainActor
final class FlatShiftTests: XCTestCase {

    private func makeCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }

    private func makeNurseJob() -> JobProfile {
        JobProfile(
            name: "St. Jude Medical Center (RN 12h)",
            role: "ICU RN",
            colorHex: "#2563EB",
            hourlyRate: 44.0,
            defaultUnpaidBreakMinutes: 30,
            dailyOTThresholdHours: 8.0,
            dailyOTMultiplier: 1.5,
            dailyDoubleTimeThresholdHours: 12.0,
            dailyDoubleTimeMultiplier: 2.0,
            weeklyOTThresholdHours: 40.0,
            weeklyOTMultiplier: 1.5,
            nightDifferentialPerHour: 4.50,
            weekendDifferentialPerHour: 3.00,
            holidayMultiplier: 2.0,
            estimatedTaxRatePercent: 22.0,
            currencySymbol: "$"
        )
    }

    func testDailyOvertimeDoubleTimeBreakAndNightDifferentialExactCents() {
        let cal = makeCalendar()
        let job = makeNurseJob()
        // 13h on clock minus 30m unpaid break = 12.5 paid hours -> 8h reg, 4h @ 1.5x, 0.5h @ 2.0x + 12.5h * $4.50 night diff
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 19, minute: 0))! // Monday
        let end = start.addingTimeInterval(13.0 * 3600)
        let shift = ShiftEntry(
            jobId: job.id,
            shiftType: .night,
            startDate: start,
            endDate: end,
            unpaidBreakMinutes: 30,
            isHoliday: false,
            applyNightDiff: true,
            applyWeekendDiff: false,
            notes: "Late handoff"
        )

        let summary = PayEngine.summarize(
            shifts: [shift],
            jobs: [job],
            periodStart: start.addingTimeInterval(-3600),
            periodEnd: end.addingTimeInterval(3600),
            calendar: cal
        )

        XCTAssertEqual(summary.totalShiftsWorked, 1)
        XCTAssertEqual(summary.totalHours, 12.5, accuracy: 0.001)
        XCTAssertEqual(summary.totalRegularHours, 8.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalOvertimeHours, 4.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalDoubleTimeHours, 0.5, accuracy: 0.001)

        // Expected exact math:
        // Reg: 8 * 44 = 352.00
        // OT:  4 * 44 * 1.5 = 264.00
        // DT:  0.5 * 44 * 2.0 = 44.00
        // Diff: 12.5 * 4.50 = 56.25
        // Gross: 716.25
        // Tax (22%): 157.58 (716.25 * 0.22 = 157.575 -> rounded 157.58)
        // Net: 716.25 - 157.58 = 558.67
        XCTAssertEqual(summary.totalRegularPay, 352.00, accuracy: 0.001)
        XCTAssertEqual(summary.totalOvertimePay, 264.00, accuracy: 0.001)
        XCTAssertEqual(summary.totalDoubleTimePay, 44.00, accuracy: 0.001)
        XCTAssertEqual(summary.totalDifferentialPay, 56.25, accuracy: 0.001)
        XCTAssertEqual(summary.totalGrossPay, 716.25, accuracy: 0.001)
        XCTAssertEqual(summary.estimatedTax, 157.58, accuracy: 0.001)
        XCTAssertEqual(summary.estimatedNetPay, 558.67, accuracy: 0.001)
        XCTAssertEqual(PayEngine.roundCents(summary.estimatedTax + summary.estimatedNetPay), summary.totalGrossPay, accuracy: 0.0001)
    }

    func testWeeklyOvertimeRolloverWithoutDoubleCounting() {
        let cal = makeCalendar()
        var job = makeNurseJob()
        job.dailyOTThresholdHours = 0 // Pure 40h/week FLSA style
        job.dailyDoubleTimeThresholdHours = 0
        job.hourlyRate = 30.0
        job.estimatedTaxRatePercent = 20.0

        // Four 12-hour day shifts Mon-Thu = 48h -> 40h regular + 8h weekly OT @ 1.5x
        let monday = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 7, minute: 0))!
        var shifts: [ShiftEntry] = []
        for d in 0..<4 {
            let s = cal.date(byAdding: .day, value: d, to: monday)!
            let e = s.addingTimeInterval(12.5 * 3600)
            shifts.append(ShiftEntry(jobId: job.id, shiftType: .day, startDate: s, endDate: e, unpaidBreakMinutes: 30))
        }

        let summary = PayEngine.summarize(
            shifts: shifts,
            jobs: [job],
            periodStart: monday.addingTimeInterval(-3600),
            periodEnd: cal.date(byAdding: .day, value: 7, to: monday)!,
            calendar: cal
        )

        XCTAssertEqual(summary.totalHours, 48.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalRegularHours, 40.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalOvertimeHours, 8.0, accuracy: 0.001)
        // Reg: 40 * 30 = 1200, OT: 8 * 45 = 360, Gross = 1560, Tax 20% = 312, Net = 1248
        XCTAssertEqual(summary.totalGrossPay, 1560.00, accuracy: 0.001)
        XCTAssertEqual(summary.estimatedTax, 312.00, accuracy: 0.001)
        XCTAssertEqual(summary.estimatedNetPay, 1248.00, accuracy: 0.001)
    }

    func testRotationPatternGeneratorAllPatterns() {
        let cal = makeCalendar()
        let job = makeNurseJob()
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 0))!

        let nurseShifts = PayEngine.generateRotationShifts(pattern: .nurse3x12, job: job, startDate: start, weeks: 2, calendar: cal)
        XCTAssertEqual(nurseShifts.count, 14)
        XCTAssertEqual(nurseShifts.filter { $0.shiftType == .night }.count, 6)
        XCTAssertEqual(nurseShifts.filter { $0.shiftType == .off }.count, 8)
        XCTAssertTrue(nurseShifts.filter { $0.shiftType == .night }.allSatisfy { $0.applyNightDiff && abs($0.payableHours - 12.0) < 0.001 })

        let dupont = PayEngine.generateRotationShifts(pattern: .dupont4Week, job: job, startDate: start, weeks: 4, calendar: cal)
        XCTAssertEqual(dupont.count, 28)
        XCTAssertEqual(dupont.filter { $0.shiftType.isPayable }.count, 14)
    }

    func testPDFTimesheetRendererProducesValidPDFKitDocument() {
        let suite = UserDefaults(suiteName: "flatshift.test.pdf.\(UUID().uuidString)")!
        let shiftStore = ShiftStore(userDefaults: suite)
        let range = PayEngine.payPeriodRange(cycle: .biweekly)
        let summary = PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: range.start,
            periodEnd: range.end
        )

        let data = PDFTimesheetRenderer.renderPDFData(
            summary: summary,
            jobTitle: "All Jobs Combined",
            employeeName: "Alex Rivera, RN",
            use24HourTime: true,
            includeBrandingFooter: true
        )

        XCTAssertGreaterThan(data.count, 4_000, "Generated PDF should contain substantial vector content")
        let pdfDoc = PDFDocument(data: data)
        XCTAssertNotNil(pdfDoc, "PDFKit must parse generated timesheet bytes cleanly")
        XCTAssertGreaterThanOrEqual(pdfDoc?.pageCount ?? 0, 1)
    }

    func testCSVExportFormatAndTotals() {
        let suite = UserDefaults(suiteName: "flatshift.test.csv.\(UUID().uuidString)")!
        let shiftStore = ShiftStore(userDefaults: suite)
        let range = PayEngine.payPeriodRange(cycle: .biweekly)
        let summary = PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: range.start,
            periodEnd: range.end
        )

        let csv = CSVTimesheetExporter.generateCSV(summary: summary, use24HourTime: true)
        let lines = csv.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        XCTAssertTrue(lines.first?.hasPrefix("Date,Job,ShiftType,ClockIn") == true)
        XCTAssertTrue(lines.last?.hasPrefix("TOTAL,") == true)
        XCTAssertEqual(lines.count, summary.totalShiftsWorked + 2)
    }

    func testJSONBackupRoundTripAndLiveClockInOut() throws {
        let suiteA = UserDefaults(suiteName: "flatshift.test.a.\(UUID().uuidString)")!
        let storeA = ShiftStore(userDefaults: suiteA)
        let job = try XCTUnwrap(storeA.jobs.first)

        // Simulate 4-hour live clock-in with 30m quick break
        let clockStart = Date().addingTimeInterval(-4.5 * 3600)
        storeA.clockIn(jobId: job.id, shiftType: .day, now: clockStart)
        storeA.toggleQuick30MinBreak()
        let saved = try XCTUnwrap(storeA.clockOutAndSave(now: Date()))
        XCTAssertEqual(saved.unpaidBreakMinutes, 30)
        XCTAssertEqual(saved.payableHours, 4.0, accuracy: 0.05)

        let jsonData = try storeA.exportBackupJSONData()
        XCTAssertGreaterThan(jsonData.count, 500)

        let suiteB = UserDefaults(suiteName: "flatshift.test.b.\(UUID().uuidString)")!
        let storeB = ShiftStore(userDefaults: suiteB)
        let importedCount = try storeB.importBackupJSONData(jsonData)
        XCTAssertEqual(importedCount, storeA.shifts.count)
        XCTAssertEqual(storeB.jobs.count, storeA.jobs.count)
        XCTAssertEqual(storeB.shifts.first?.id, storeA.shifts.first?.id)
    }

    func testHolidayMultiplierAndMultiJobPennySumInvariant() {
        let cal = makeCalendar()
        let job = makeNurseJob()
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 7, minute: 0))!
        let end = start.addingTimeInterval(12.5 * 3600) // 12h paid holiday @ 2.0x = $44 * 2 * 12 = $1056
        let holidayShift = ShiftEntry(
            jobId: job.id,
            shiftType: .day,
            startDate: start,
            endDate: end,
            unpaidBreakMinutes: 30,
            isHoliday: true,
            applyNightDiff: false,
            applyWeekendDiff: false
        )
        let summary = PayEngine.summarize(
            shifts: [holidayShift],
            jobs: [job],
            periodStart: start.addingTimeInterval(-3600),
            periodEnd: end.addingTimeInterval(3600),
            calendar: cal
        )
        XCTAssertEqual(summary.totalDoubleTimeHours, 12.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalDoubleTimePay, 1056.00, accuracy: 0.001)
        XCTAssertEqual(summary.totalGrossPay, 1056.00, accuracy: 0.001)
        XCTAssertEqual(
            PayEngine.roundCents(summary.totalRegularPay + summary.totalOvertimePay + summary.totalDoubleTimePay + summary.totalDifferentialPay),
            summary.totalGrossPay,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PayEngine.roundCents(summary.estimatedTax + summary.estimatedNetPay),
            summary.totalGrossPay,
            accuracy: 0.0001
        )
    }
}
