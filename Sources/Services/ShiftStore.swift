import Foundation
import SwiftUI

@MainActor
final class ShiftStore: ObservableObject {
    @Published var jobs: [JobProfile] = []
    @Published var shifts: [ShiftEntry] = []
    @Published var activeSession: ActiveClockSession? = nil
    @Published var preferences: AppPreferences = AppPreferences()

    private let jobsKey = "flatshift.jobs.v1"
    private let shiftsKey = "flatshift.shifts.v1"
    private let sessionKey = "flatshift.activeSession.v1"
    private let prefsKey = "flatshift.prefs.v1"
    private let seededKey = "flatshift.seeded.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        load()
        applyLaunchOverridesIfNeeded()
    }

    private let defaults: UserDefaults

    private func load() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601

        if let data = defaults.data(forKey: prefsKey),
           let loaded = try? dec.decode(AppPreferences.self, from: data) {
            preferences = loaded
        } else {
            preferences.currencySymbol = L10n.t("$", "¥", "HK$")
            preferences.employeeName = L10n.t("Alex Rivera, RN", "林晓明", "陳家豪 RN")
        }

        if let data = defaults.data(forKey: jobsKey),
           let loaded = try? dec.decode([JobProfile].self, from: data) {
            jobs = loaded
        }

        if let data = defaults.data(forKey: shiftsKey),
           let loaded = try? dec.decode([ShiftEntry].self, from: data) {
            shifts = loaded
        }

        if let data = defaults.data(forKey: sessionKey),
           let loaded = try? dec.decode(ActiveClockSession.self, from: data) {
            activeSession = loaded
        }

        if !defaults.bool(forKey: seededKey) && jobs.isEmpty {
            seedRealisticStarterData()
            defaults.set(true, forKey: seededKey)
        }
    }

    private func applyLaunchOverridesIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ui_theme"), idx + 1 < args.count {
            let mode = args[idx + 1].lowercased()
            if mode == "dark" {
                preferences.appearanceMode = .nightDark
            } else if mode == "light" {
                preferences.appearanceMode = .light
            }
        }
    }

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(jobs) { defaults.set(d, forKey: jobsKey) }
        if let d = try? enc.encode(shifts) { defaults.set(d, forKey: shiftsKey) }
        if let d = try? enc.encode(preferences) { defaults.set(d, forKey: prefsKey) }
        if let session = activeSession, let d = try? enc.encode(session) {
            defaults.set(d, forKey: sessionKey)
        } else {
            defaults.removeObject(forKey: sessionKey)
        }
    }

    // MARK: - Jobs CRUD
    func upsertJob(_ job: JobProfile) {
        if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[idx] = job
        } else {
            jobs.append(job)
        }
        save()
    }

    func deleteJob(_ job: JobProfile) {
        jobs.removeAll { $0.id == job.id }
        shifts.removeAll { $0.jobId == job.id }
        if activeSession?.jobId == job.id {
            activeSession = nil
        }
        save()
    }

    func job(for id: UUID) -> JobProfile? {
        jobs.first { $0.id == id }
    }

    // MARK: - Shifts CRUD
    func upsertShift(_ shift: ShiftEntry) {
        if let idx = shifts.firstIndex(where: { $0.id == shift.id }) {
            shifts[idx] = shift
        } else {
            shifts.append(shift)
        }
        shifts.sort { $0.startDate > $1.startDate }
        save()
    }

    func deleteShift(_ shift: ShiftEntry) {
        shifts.removeAll { $0.id == shift.id }
        save()
    }

    func applyRotation(
        pattern: RotationPattern,
        job: JobProfile,
        startDate: Date,
        weeks: Int,
        dayStartHour: Int = 7,
        nightStartHour: Int = 19,
        shiftDurationHours: Double? = nil,
        replaceExistingForJobInRange: Bool = true
    ) -> Int {
        let cal = Calendar.current
        let generated = PayEngine.generateRotationShifts(
            pattern: pattern,
            job: job,
            startDate: startDate,
            weeks: weeks,
            dayStartHour: dayStartHour,
            nightStartHour: nightStartHour,
            shiftDurationHours: shiftDurationHours,
            calendar: cal
        )
        if replaceExistingForJobInRange {
            let rangeStart = cal.startOfDay(for: startDate)
            let rangeEnd = cal.date(byAdding: .day, value: weeks * 7, to: rangeStart) ?? rangeStart
            shifts.removeAll { s in
                s.jobId == job.id && s.startDate >= rangeStart && s.startDate < rangeEnd
            }
        }
        shifts.append(contentsOf: generated)
        shifts.sort { $0.startDate > $1.startDate }
        save()
        return generated.count
    }

    // MARK: - Live Clock In / Break / Clock Out
    func clockIn(jobId: UUID, shiftType: ShiftType, now: Date = Date()) {
        activeSession = ActiveClockSession(
            jobId: jobId,
            shiftType: shiftType,
            clockInDate: now,
            accumulatedBreakSeconds: 0,
            breakStartedAt: nil,
            quickBreakMinutes: 0,
            applyNightDiff: shiftType == .night,
            applyWeekendDiff: PayEngine.isWeekend(now),
            isHoliday: false,
            notes: ""
        )
        save()
    }

    func toggleBreak(now: Date = Date()) {
        guard var session = activeSession else { return }
        if let bStart = session.breakStartedAt {
            session.accumulatedBreakSeconds += max(0, now.timeIntervalSince(bStart))
            session.breakStartedAt = nil
        } else {
            session.breakStartedAt = now
        }
        activeSession = session
        save()
    }

    func toggleQuick30MinBreak() {
        guard var session = activeSession else { return }
        session.quickBreakMinutes = (session.quickBreakMinutes == 0) ? 30 : 0
        activeSession = session
        save()
    }

    func toggleActiveNightDiff() {
        guard var session = activeSession else { return }
        session.applyNightDiff.toggle()
        activeSession = session
        save()
    }

    @discardableResult
    func clockOutAndSave(now: Date = Date()) -> ShiftEntry? {
        guard let session = activeSession else { return nil }
        let breakMins = session.totalBreakMinutes(at: now)
        // Ensure at least 1 minute if clocked out immediately during quick testing
        let endDate = max(now, session.clockInDate.addingTimeInterval(60))
        let entry = ShiftEntry(
            jobId: session.jobId,
            shiftType: session.shiftType,
            startDate: session.clockInDate,
            endDate: endDate,
            unpaidBreakMinutes: breakMins,
            isHoliday: session.isHoliday,
            applyNightDiff: session.applyNightDiff,
            applyWeekendDiff: session.applyWeekendDiff,
            notes: session.notes.isEmpty ? L10n.t("Live Clock-In Shift", "实时打卡班次") : session.notes
        )
        activeSession = nil
        upsertShift(entry)
        return entry
    }

    func cancelActiveSession() {
        activeSession = nil
        save()
    }

    // MARK: - JSON Backup & Restore
    func exportBackupJSONData() throws -> Data {
        let backup = FlatShiftBackup(
            version: 1,
            exportedAt: Date(),
            jobs: jobs,
            shifts: shifts,
            preferences: preferences
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(backup)
    }

    func importBackupJSONData(_ data: Data) throws -> Int {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let backup = try dec.decode(FlatShiftBackup.self, from: data)
        guard !backup.jobs.isEmpty else {
            throw NSError(domain: "FlatShift", code: 400, userInfo: [NSLocalizedDescriptionKey: L10n.t("Backup contains no jobs.", "备份文件中没有工作配置。")])
        }
        jobs = backup.jobs
        shifts = backup.shifts.sorted { $0.startDate > $1.startDate }
        preferences = backup.preferences
        activeSession = nil
        save()
        return shifts.count
    }

    // MARK: - Day-0 Onboarding Quick Setup
    func applyOnboardingSetup(
        pattern: RotationPattern,
        hourlyRate: Double,
        includeNightDiff: Bool,
        referenceDate: Date = Date()
    ) {
        let curr = L10n.t("$", "¥", "HK$")
        let defaultNightDiff: Double = L10n.currentLanguage == .zhHant ? 35.0 : (L10n.isChinese ? 12.0 : 4.5)
        let defaultWeekendDiff: Double = L10n.currentLanguage == .zhHant ? 25.0 : (L10n.isChinese ? 8.0 : 3.0)
        let defaultTax: Double = L10n.isChinese ? 10.0 : 22.0

        let jobName: String = {
            switch pattern {
            case .nurse3x12:
                return L10n.t("Hospital 3×12 Shift", "医院 12h 倒班主职", "醫院 12h 輪班正職")
            case .panama223:
                return L10n.t("2-2-3 Panama Rotation", "2-2-3 巴拿马轮班", "2-2-3 巴拿馬輪班")
            default:
                return L10n.t("Primary Shift Job", "我的主工作", "我的主要工作")
            }
        }()

        let primaryJob = JobProfile(
            name: jobName,
            role: pattern.title,
            colorHex: "#2563EB",
            hourlyRate: max(1.0, hourlyRate),
            defaultUnpaidBreakMinutes: 30,
            dailyOTThresholdHours: 8.0,
            dailyOTMultiplier: 1.5,
            dailyDoubleTimeThresholdHours: 12.0,
            dailyDoubleTimeMultiplier: 2.0,
            weeklyOTThresholdHours: 40.0,
            weeklyOTMultiplier: 1.5,
            nightDifferentialPerHour: includeNightDiff ? defaultNightDiff : 0.0,
            weekendDifferentialPerHour: defaultWeekendDiff,
            holidayMultiplier: 2.0,
            estimatedTaxRatePercent: defaultTax,
            currencySymbol: curr
        )

        preferences.currencySymbol = curr
        jobs = [primaryJob]
        shifts = []
        activeSession = nil

        let cal = Calendar.current
        let period = PayEngine.payPeriodRange(cycle: preferences.payPeriodCycle, referenceDate: referenceDate, offset: 0, calendar: cal)
        _ = applyRotation(
            pattern: pattern,
            job: primaryJob,
            startDate: period.start,
            weeks: StoreManager.freeRotationMaxWeeks,
            replaceExistingForJobInRange: true
        )
    }

    // MARK: - Starter Data (Localized EN + ZH-Hans + ZH-Hant)
    func seedRealisticStarterData(referenceDate: Date = Date()) {
        let lang = L10n.currentLanguage
        let curr = L10n.t("$", "¥", "HK$")
        preferences.currencySymbol = curr
        preferences.employeeName = L10n.t("Alex Rivera, RN", "林晓明 · 急诊科护士", "陳家豪 · 急症室護士")
        preferences.payPeriodCycle = .biweekly
        preferences.use24HourTime = true

        let mainJob = JobProfile(
            name: L10n.t("St. Jude Medical Center (RN 12h)", "仁和医院急诊科（12h倒班）", "仁安醫院急症科（12h輪班）"),
            role: L10n.t("ICU Staff Nurse · 12h", "急诊科三班倒护师", "深切治療部護士 · 12h"),
            colorHex: "#2563EB",
            hourlyRate: lang == .zhHant ? 220.0 : (lang == .zhHans ? 65.0 : 44.0),
            defaultUnpaidBreakMinutes: 30,
            dailyOTThresholdHours: 8.0,
            dailyOTMultiplier: 1.5,
            dailyDoubleTimeThresholdHours: 12.0,
            dailyDoubleTimeMultiplier: 2.0,
            weeklyOTThresholdHours: 40.0,
            weeklyOTMultiplier: 1.5,
            nightDifferentialPerHour: lang == .zhHant ? 35.0 : (lang == .zhHans ? 12.0 : 4.5),
            weekendDifferentialPerHour: lang == .zhHant ? 25.0 : (lang == .zhHans ? 8.0 : 3.0),
            holidayMultiplier: 2.0,
            estimatedTaxRatePercent: lang == .en ? 22.0 : 12.0,
            currencySymbol: curr
        )

        let sideJob = JobProfile(
            name: L10n.t("Weekend Carpentry Side Work", "周末全屋木作安装副业", "週末兼職安裝副業"),
            role: L10n.t("Finish Trim & Custom Framing", "精装木工与定制安装", "客製木工與安裝"),
            colorHex: "#10B981",
            hourlyRate: lang == .zhHant ? 260.0 : (lang == .zhHans ? 90.0 : 55.0),
            defaultUnpaidBreakMinutes: 30,
            dailyOTThresholdHours: 8.0,
            dailyOTMultiplier: 1.5,
            dailyDoubleTimeThresholdHours: 12.0,
            dailyDoubleTimeMultiplier: 2.0,
            weeklyOTThresholdHours: 40.0,
            weeklyOTMultiplier: 1.5,
            nightDifferentialPerHour: 0,
            weekendDifferentialPerHour: 0,
            holidayMultiplier: 1.5,
            estimatedTaxRatePercent: lang == .en ? 24.0 : 8.0,
            currencySymbol: curr
        )

        jobs = [mainJob, sideJob]

        let cal = Calendar.current
        let period = PayEngine.payPeriodRange(cycle: .biweekly, referenceDate: referenceDate, offset: 0, calendar: cal)
        let pStart = cal.startOfDay(for: period.start)

        func makeShift(
            dayOffset: Int,
            job: JobProfile,
            type: ShiftType,
            startHour: Int,
            paidHours: Double,
            breakMins: Int,
            nightDiff: Bool = false,
            holiday: Bool = false,
            noteEN: String,
            noteZH: String
        ) -> ShiftEntry {
            let day = cal.date(byAdding: .day, value: dayOffset, to: pStart) ?? pStart
            let s = cal.date(byAdding: .hour, value: startHour, to: day) ?? day
            let totalMins = Int(round(paidHours * 60.0)) + breakMins
            let e = type == .off ? s : (cal.date(byAdding: .minute, value: totalMins, to: s) ?? s)
            return ShiftEntry(
                jobId: job.id,
                shiftType: type,
                startDate: s,
                endDate: e,
                unpaidBreakMinutes: type == .off ? 0 : breakMins,
                isHoliday: holiday,
                applyNightDiff: nightDiff,
                applyWeekendDiff: type.isPayable && PayEngine.isWeekend(s, calendar: cal),
                notes: L10n.isChinese ? noteZH : noteEN
            )
        }

        // Prior bi-weekly shifts (dayOffset -14..-1) + current bi-weekly shifts (dayOffset 0..13)
        // so the monthly shift calendar is richly populated while current pay period shows exact 8 shifts!
        shifts = [
            // Prior bi-weekly period (populates earlier weeks of current month calendar)
            makeShift(dayOffset: -14, job: mainJob, type: .day, startHour: 7, paidHours: 12.0, breakMins: 30, noteEN: "ICU Pod A · Day Shift", noteZH: "急诊重症监护 · 白班"),
            makeShift(dayOffset: -13, job: mainJob, type: .day, startHour: 7, paidHours: 12.0, breakMins: 30, noteEN: "ICU Pod A · Day Shift", noteZH: "急诊重症监护 · 白班"),
            makeShift(dayOffset: -12, job: mainJob, type: .day, startHour: 7, paidHours: 12.0, breakMins: 30, noteEN: "ICU Pod A · Day Shift", noteZH: "急诊重症监护 · 白班"),
            makeShift(dayOffset: -11, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Scheduled Off", noteZH: "轮休"),
            makeShift(dayOffset: -10, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Scheduled Off", noteZH: "轮休"),
            makeShift(dayOffset: -9, job: sideJob, type: .swing, startHour: 13, paidHours: 6.0, breakMins: 30, noteEN: "Cedar Deck Railings", noteZH: "实木阳台护栏安装"),
            makeShift(dayOffset: -8, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Family Rest Day", noteZH: "休息日"),
            makeShift(dayOffset: -7, job: mainJob, type: .night, startHour: 19, paidHours: 12.0, breakMins: 30, nightDiff: true, noteEN: "ICU Pod B · Night Rotation", noteZH: "急诊重症监护 · 夜班"),
            makeShift(dayOffset: -6, job: mainJob, type: .night, startHour: 19, paidHours: 12.0, breakMins: 30, nightDiff: true, noteEN: "ICU Pod B · Night Rotation", noteZH: "急诊重症监护 · 夜班"),
            makeShift(dayOffset: -5, job: mainJob, type: .overtime, startHour: 15, paidHours: 8.0, breakMins: 30, noteEN: "Extra Shift Coverage", noteZH: "临时顶班加班"),
            makeShift(dayOffset: -4, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Post-Night Recovery", noteZH: "夜班后休整"),
            makeShift(dayOffset: -3, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Scheduled Off", noteZH: "轮休"),
            makeShift(dayOffset: -2, job: sideJob, type: .day, startHour: 8, paidHours: 7.0, breakMins: 30, noteEN: "Kitchen Cabinet Trim", noteZH: "橱柜收口与门板调试"),
            makeShift(dayOffset: -1, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Rest Before Rotation", noteZH: "倒班前休整"),
            // Current bi-weekly pay period (8 worked shifts + 4 off days)
            makeShift(dayOffset: 0, job: mainJob, type: .night, startHour: 19, paidHours: 12.0, breakMins: 30, nightDiff: true, noteEN: "ICU Pod B · Night Rotation", noteZH: "急诊重症监护 · 夜班"),
            makeShift(dayOffset: 1, job: mainJob, type: .night, startHour: 19, paidHours: 12.0, breakMins: 30, nightDiff: true, noteEN: "ICU Pod B · Night Rotation", noteZH: "急诊重症监护 · 夜班"),
            makeShift(dayOffset: 2, job: mainJob, type: .night, startHour: 19, paidHours: 12.5, breakMins: 30, nightDiff: true, noteEN: "Late Handoff (+30m Double Time)", noteZH: "交接班延时30分钟（双倍算薪）"),
            makeShift(dayOffset: 3, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Post-Night Recovery", noteZH: "夜班后休整"),
            makeShift(dayOffset: 4, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Scheduled Off", noteZH: "轮休"),
            makeShift(dayOffset: 5, job: sideJob, type: .day, startHour: 8, paidHours: 6.5, breakMins: 30, noteEN: "Oak Crown Molding · Elm St", noteZH: "橡木护墙板与吊柜安装"),
            makeShift(dayOffset: 6, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Family Day", noteZH: "休息日"),
            makeShift(dayOffset: 7, job: mainJob, type: .day, startHour: 7, paidHours: 12.0, breakMins: 30, noteEN: "Step-Down Ward · Day Shift", noteZH: "观察病房 · 白班12h"),
            makeShift(dayOffset: 8, job: mainJob, type: .day, startHour: 7, paidHours: 12.0, breakMins: 30, noteEN: "Step-Down Ward · Day Shift", noteZH: "观察病房 · 白班12h"),
            makeShift(dayOffset: 9, job: mainJob, type: .overtime, startHour: 15, paidHours: 8.0, breakMins: 30, noteEN: "Short-Staffed Call-In Bonus Shift", noteZH: "科室缺人紧急顶班（全程1.5x）"),
            makeShift(dayOffset: 10, job: mainJob, type: .off, startHour: 9, paidHours: 0, breakMins: 0, noteEN: "Scheduled Off", noteZH: "调休"),
            makeShift(dayOffset: 12, job: sideJob, type: .swing, startHour: 13, paidHours: 5.5, breakMins: 30, noteEN: "Custom Pantry Shelving", noteZH: "全屋定制收纳柜收口"),
        ].sorted { $0.startDate > $1.startDate }

        save()
    }
}
