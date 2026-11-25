import PDFKit
import UIKit
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

    // MARK: - v1.0.1 Upgrade Tests

    func testTraditionalChineseLanguageDetectionAndThreeArgTranslation() {
        let original = L10n.forcedLanguage
        defer { L10n.forcedLanguage = original }

        for code in ["zh-Hant", "zh-Hant-TW", "zh-Hant-HK", "zh-HK", "zh-TW", "zh-MO", "zh_Hant_HK"] {
            XCTAssertEqual(L10n.resolveLanguage(from: code), .zhHant, "Expected .zhHant for \(code)")
        }
        for code in ["zh-Hans", "zh-CN", "zh-SG", "zh_Hans_CN"] {
            XCTAssertEqual(L10n.resolveLanguage(from: code), .zhHans, "Expected .zhHans for \(code)")
        }
        for code in ["en", "en-US", "de-DE", "ja-JP"] {
            XCTAssertEqual(L10n.resolveLanguage(from: code), .en, "Expected .en for \(code)")
        }

        L10n.forcedLanguage = "zh-HK"
        XCTAssertTrue(L10n.isChinese)
        XCTAssertTrue(L10n.isTraditionalChinese)
        XCTAssertEqual(L10n.t("Schedule", "排班表", "排班更表"), "排班更表")
        XCTAssertEqual(L10n.t("Overtime Calc", "加班费计算", "加班費試算"), "加班費試算")
        XCTAssertEqual(L10n.t("Night Diff", "夜班津贴", "夜班津貼"), "夜班津貼")
        XCTAssertEqual(L10n.t("Lifetime", "永久买断", "永久買斷"), "永久買斷")
        // Backward compatibility of 2-arg t(_:_:)
        XCTAssertEqual(L10n.t("Hello", "你好"), "你好")

        L10n.forcedLanguage = "zh-Hans"
        XCTAssertEqual(L10n.t("Lifetime", "永久买断", "永久買斷"), "永久买断")

        L10n.forcedLanguage = "en-US"
        XCTAssertEqual(L10n.t("Lifetime", "永久买断", "永久買斷"), "Lifetime")
    }

    func testStoreManagerLifetimeSinglePDFCapAndRotationLimit() {
        let originalLang = L10n.forcedLanguage
        defer { L10n.forcedLanguage = originalLang }
        L10n.forcedLanguage = "en-US"

        let suiteName = "flatshift.test.store.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let mgr = StoreManager(userDefaults: suite, startListeners: false)
        XCTAssertFalse(mgr.isPro)
        XCTAssertEqual(StoreManager.freeLifetimePDFExportLimit, 1)
        XCTAssertEqual(StoreManager.freeRotationMaxWeeks, 2)
        XCTAssertEqual(mgr.remainingFreePDFExports, 1)
        XCTAssertTrue(mgr.canExportFreePDF)

        // Rotation painter free cap: <= 2 weeks allowed, > 2 weeks requires Pro
        XCTAssertTrue(mgr.canPaintRotation(weeks: 1))
        XCTAssertTrue(mgr.canPaintRotation(weeks: 2))
        XCTAssertFalse(mgr.canPaintRotation(weeks: 3))
        XCTAssertFalse(mgr.canPaintRotation(weeks: 52))

        // After 1st PDF export, lifetime free PDF cap is permanently exhausted for free tier
        mgr.recordPDFExport()
        XCTAssertEqual(mgr.remainingFreePDFExports, 0)
        XCTAssertFalse(mgr.canExportFreePDF)

        // Persists across fresh StoreManager instance
        let reloaded = StoreManager(userDefaults: suite, startListeners: false)
        XCTAssertEqual(reloaded.remainingFreePDFExports, 0)
        XCTAssertFalse(reloaded.canExportFreePDF)

        // Updated v1.0.1 fallback pricing & Day-5 trial reminder
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.lifetime), "$12.99")
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.yearly), "$7.99")
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.monthly), "$3.99")
        XCTAssertEqual(StoreManager.trialReminderDelaySeconds, 5 * 24 * 3600, accuracy: 0.1)

        L10n.forcedLanguage = "zh-Hant"
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.lifetime), "HK$78")
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.yearly), "HK$48")
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.monthly), "HK$18")

        L10n.forcedLanguage = "zh-Hans"
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.lifetime), "¥48")
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.yearly), "¥28")
        XCTAssertEqual(mgr.displayPrice(for: FlatShiftProductID.monthly), "¥12")
    }

    func testScheduleImageRendererProducesValidPNG() {
        let suiteName = "flatshift.test.schedimg.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let shiftStore = ShiftStore(userDefaults: suite)
        let now = Date()

        let pngWithBadge = ScheduleImageRenderer.renderMonthlySchedulePNG(
            monthDate: now,
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            employeeName: "Alex Rivera, RN",
            use24HourTime: true,
            includeBrandingBadge: true,
            darkTheme: false
        )
        XCTAssertNotNil(pngWithBadge)
        guard let data = pngWithBadge else { return }
        XCTAssertGreaterThan(data.count, 10_000, "Rendered monthly schedule PNG should be non-empty high-res output")
        // Verify PNG magic header bytes: 89 50 4E 47
        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])

        let decoded = UIImage(data: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.size.width ?? 0, ScheduleImageRenderer.canvasSize.width, accuracy: 1.0)
        XCTAssertEqual(decoded?.size.height ?? 0, ScheduleImageRenderer.canvasSize.height, accuracy: 1.0)

        let pngCleanPro = ScheduleImageRenderer.renderMonthlySchedulePNG(
            monthDate: now,
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            employeeName: "Alex Rivera, RN",
            use24HourTime: false,
            includeBrandingBadge: false,
            darkTheme: true
        )
        XCTAssertNotNil(pngCleanPro)
        XCTAssertGreaterThan(pngCleanPro?.count ?? 0, 10_000)
    }

    func testRegionalPaywallStyleRouting() {
        // Anglo ROI regions & default
        for code in ["US", "CA", "AU", "NZ", "BR", "", nil] {
            let style = PaywallRegionStyle.resolve(regionCode: code)
            XCTAssertEqual(style, .angloROI, "Expected .angloROI for \(code ?? "nil")")
            XCTAssertEqual(style.defaultSelectedProductID, FlatShiftProductID.yearly)
        }

        // EU Privacy + Lifetime regions
        for code in ["DE", "CH", "AT", "GB", "FR", "NL", "SE", "NO", "DK", "FI", "IE", "IT", "ES"] {
            let style = PaywallRegionStyle.resolve(regionCode: code)
            XCTAssertEqual(style, .euPrivacyLifetime, "Expected .euPrivacyLifetime for \(code)")
            XCTAssertEqual(style.defaultSelectedProductID, FlatShiftProductID.lifetime)
        }

        // East Asia High-Detail Trust regions
        for code in ["JP", "KR", "TW", "HK", "MO", "SG"] {
            let style = PaywallRegionStyle.resolve(regionCode: code)
            XCTAssertEqual(style, .eastAsiaDetail, "Expected .eastAsiaDetail for \(code)")
            XCTAssertEqual(style.defaultSelectedProductID, FlatShiftProductID.lifetime)
        }
    }

    func testOnboardingSetupAndOTNetCalculation() {
        let suiteName = "flatshift.test.onboarding.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let shiftStore = ShiftStore(userDefaults: suite)
        shiftStore.applyOnboardingSetup(pattern: .nurse3x12, hourlyRate: 44.0, includeNightDiff: true)

        XCTAssertEqual(shiftStore.jobs.count, 1)
        XCTAssertEqual(shiftStore.shifts.count, 14)

        let range = PayEngine.payPeriodRange(cycle: shiftStore.preferences.payPeriodCycle)
        let summary = PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: range.start,
            periodEnd: range.end
        )
        XCTAssertEqual(summary.totalShiftsWorked, 6)
        XCTAssertGreaterThan(summary.totalOvertimePay, 0)
        XCTAssertGreaterThan(summary.totalDifferentialPay, 0)
        XCTAssertGreaterThan(summary.estimatedNetPay, 0)
        XCTAssertEqual(
            PayEngine.roundCents(summary.estimatedTax + summary.estimatedNetPay),
            summary.totalGrossPay,
            accuracy: 0.0001
        )
    }

    func testReviewPromptManagerHappyPathTriggersAndCooldown() {
        let suiteName = "flatshift.test.review.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let metrics = FunnelMetrics(userDefaults: suite)
        let manager = ReviewPromptManager(userDefaults: suite, metrics: metrics)

        let day0 = Date(timeIntervalSince1970: 1_764_000_000)
        XCTAssertFalse(manager.isShowingPrompt)

        // 1st and 2nd logged shift should NOT prompt yet
        manager.recordShiftLogged(now: day0)
        manager.recordShiftLogged(now: day0)
        XCTAssertFalse(manager.isShowingPrompt)
        XCTAssertEqual(metrics.count(for: .shiftLogged), 2)

        // 3rd logged shift triggers review prompt
        manager.recordShiftLogged(now: day0)
        XCTAssertTrue(manager.isShowingPrompt)
        XCTAssertEqual(metrics.count(for: .reviewGateShown), 1)
        manager.markPositiveRatingTapped()
        XCTAssertFalse(manager.isShowingPrompt)
        XCTAssertEqual(metrics.count(for: .reviewPositiveTapped), 1)

        // Within 90-day cooldown: 1st schedule image share should NOT re-prompt
        let day30 = day0.addingTimeInterval(30 * 86_400)
        manager.recordScheduleImageShared(now: day30)
        XCTAssertFalse(manager.isShowingPrompt)
        XCTAssertEqual(metrics.count(for: .scheduleImageShared), 1)

        // After 91 days: 1st PDF export triggers cleanly again
        let day91 = day0.addingTimeInterval(91 * 86_400)
        manager.recordPDFExported(now: day91)
        XCTAssertTrue(manager.isShowingPrompt)
        XCTAssertEqual(metrics.count(for: .pdfExported), 1)
        XCTAssertEqual(metrics.count(for: .reviewGateShown), 2)
    }
}
