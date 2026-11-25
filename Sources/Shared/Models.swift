import Foundation
import SwiftUI

enum ShiftType: String, Codable, CaseIterable, Identifiable {
    case day
    case night
    case swing
    case overtime
    case pto
    case off

    var id: String { rawValue }

    var shortBadge: String {
        switch self {
        case .day: return L10n.t("DAY", "白班")
        case .night: return L10n.t("NIGHT", "夜班")
        case .swing: return L10n.t("SWING", "中班")
        case .overtime: return L10n.t("OT", "加班")
        case .pto: return L10n.t("PTO", "带薪假")
        case .off: return L10n.t("OFF", "休")
        }
    }

    var fullName: String {
        switch self {
        case .day: return L10n.t("Day Shift", "白班")
        case .night: return L10n.t("Night Shift", "夜班")
        case .swing: return L10n.t("Swing Shift", "中班")
        case .overtime: return L10n.t("Overtime Shift", "加班班次")
        case .pto: return L10n.t("Paid Time Off", "带薪休假")
        case .off: return L10n.t("Day Off", "休息日")
        }
    }

    var color: Color {
        switch self {
        case .day: return ShiftTheme.shiftMint
        case .night: return ShiftTheme.nightViolet
        case .swing: return ShiftTheme.swingTeal
        case .overtime: return ShiftTheme.overtimeAmber
        case .pto: return ShiftTheme.ptoRose
        case .off: return ShiftTheme.offSlate
        }
    }

    var iconName: String {
        switch self {
        case .day: return "sun.max.fill"
        case .night: return "moon.stars.fill"
        case .swing: return "sunset.fill"
        case .overtime: return "bolt.fill"
        case .pto: return "umbrella.fill"
        case .off: return "bed.double.fill"
        }
    }

    var isPayable: Bool {
        self != .off
    }
}

enum PayPeriodCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case biweekly
    case semimonthly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: return L10n.t("Weekly", "每周")
        case .biweekly: return L10n.t("Bi-Weekly", "双周")
        case .semimonthly: return L10n.t("Semi-Monthly", "半月")
        case .monthly: return L10n.t("Monthly", "每月")
        }
    }
}

struct JobProfile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var role: String
    var colorHex: String
    var hourlyRate: Double
    var defaultUnpaidBreakMinutes: Int
    var dailyOTThresholdHours: Double          // e.g., 8.0 (0 = disabled)
    var dailyOTMultiplier: Double              // e.g., 1.5
    var dailyDoubleTimeThresholdHours: Double  // e.g., 12.0 (0 = disabled)
    var dailyDoubleTimeMultiplier: Double      // e.g., 2.0
    var weeklyOTThresholdHours: Double         // e.g., 40.0 (0 = disabled)
    var weeklyOTMultiplier: Double             // e.g., 1.5
    var nightDifferentialPerHour: Double       // e.g., 4.50
    var weekendDifferentialPerHour: Double     // e.g., 3.00
    var holidayMultiplier: Double              // e.g., 2.0
    var estimatedTaxRatePercent: Double        // e.g., 22.0
    var currencySymbol: String

    var swatchColor: Color { Color(hex: colorHex) }

    var ruleSummary: String {
        var parts: [String] = []
        if dailyOTThresholdHours > 0 {
            parts.append(L10n.t(">\(Self.trim(dailyOTThresholdHours))h @ \(Self.trim(dailyOTMultiplier))x", "日>\(Self.trim(dailyOTThresholdHours))h \(Self.trim(dailyOTMultiplier))倍"))
        }
        if weeklyOTThresholdHours > 0 {
            parts.append(L10n.t(">\(Self.trim(weeklyOTThresholdHours))h/wk", "周>\(Self.trim(weeklyOTThresholdHours))h"))
        }
        if nightDifferentialPerHour > 0 {
            parts.append(L10n.t("Night +\(currencySymbol)\(String(format: "%.2f", nightDifferentialPerHour))", "夜班+\(currencySymbol)\(String(format: "%.2f", nightDifferentialPerHour))"))
        }
        return parts.joined(separator: " · ")
    }

    private static func trim(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct ShiftEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var jobId: UUID
    var shiftType: ShiftType
    var startDate: Date
    var endDate: Date
    var unpaidBreakMinutes: Int
    var isHoliday: Bool = false
    var applyNightDiff: Bool = false
    var applyWeekendDiff: Bool = false
    var customHourlyRate: Double? = nil
    var notes: String = ""

    var rawMinutes: Int {
        guard shiftType.isPayable else { return 0 }
        return max(0, Int(round(endDate.timeIntervalSince(startDate) / 60.0)))
    }

    var payableMinutes: Int {
        guard shiftType.isPayable else { return 0 }
        return max(0, rawMinutes - max(0, unpaidBreakMinutes))
    }

    var payableHours: Double {
        Double(payableMinutes) / 60.0
    }
}

struct ActiveClockSession: Codable, Equatable {
    var jobId: UUID
    var shiftType: ShiftType
    var clockInDate: Date
    var accumulatedBreakSeconds: TimeInterval = 0
    var breakStartedAt: Date? = nil
    var quickBreakMinutes: Int = 0
    var applyNightDiff: Bool = false
    var applyWeekendDiff: Bool = false
    var isHoliday: Bool = false
    var notes: String = ""

    var isOnBreak: Bool { breakStartedAt != nil }

    func totalBreakMinutes(at now: Date) -> Int {
        let liveBreak = breakStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let totalSecs = accumulatedBreakSeconds + liveBreak
        return Int(round(totalSecs / 60.0)) + quickBreakMinutes
    }

    func elapsedWorkSeconds(at now: Date) -> TimeInterval {
        let gross = max(0, now.timeIntervalSince(clockInDate))
        let liveBreak = breakStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let totalBreak = accumulatedBreakSeconds + liveBreak + Double(quickBreakMinutes * 60)
        return max(0, gross - totalBreak)
    }
}

enum RotationPattern: String, CaseIterable, Identifiable {
    case nurse3x12
    case dupont4Week
    case panama223
    case fourOnFourOff
    case monFri8h

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nurse3x12: return L10n.t("Nurse 3×12 (3 On / 4 Off)", "护士 3×12 小时制（上3休4）")
        case .dupont4Week: return L10n.t("DuPont 4-Week (12h Day/Night)", "杜邦四周倒班制（12h白/夜）")
        case .panama223: return L10n.t("2-2-3 Panama (Pitman 12h)", "2-2-3 巴拿马轮班制（12h）")
        case .fourOnFourOff: return L10n.t("4-On / 4-Off (Day & Night)", "做四休四倒班制（白/夜）")
        case .monFri8h: return L10n.t("Mon–Fri Standard 8h", "标准周一至周五 8小时")
        }
    }

    var subtitle: String {
        switch self {
        case .nurse3x12: return L10n.t("3 consecutive 12h shifts, 4 days recovery", "连续3天12小时班，连休4天")
        case .dupont4Week: return L10n.t("4N·3O·3D·1O·3N·3O·4D·7O industrial cycle", "经典28天四班三倒工业循环，含7天长休")
        case .panama223: return L10n.t("2 On · 2 Off · 3 On · 2 Off · 2 On · 3 Off", "14天双周轮换，隔周享完整长周末")
        case .fourOnFourOff: return L10n.t("4 Day · 4 Off · 4 Night · 4 Off", "4白班·4休·4夜班·4休循环")
        case .monFri8h: return L10n.t("5 weekday shifts + Sat/Sun off", "工作日白班，周末双休")
        }
    }

    var defaultHours: Double {
        self == .monFri8h ? 8.0 : 12.0
    }

    /// Cycle sequence of ShiftType per day starting from anchor date
    var cycle: [ShiftType] {
        switch self {
        case .nurse3x12:
            return [.night, .night, .night, .off, .off, .off, .off]
        case .dupont4Week:
            return [
                .night, .night, .night, .night, .off, .off, .off,
                .day, .day, .day, .off, .night, .night, .night,
                .off, .off, .off, .day, .day, .day, .day,
                .off, .off, .off, .off, .off, .off, .off
            ]
        case .panama223:
            return [
                .day, .day, .off, .off, .day, .day, .day,
                .off, .off, .day, .day, .off, .off, .off
            ]
        case .fourOnFourOff:
            return [
                .day, .day, .day, .day, .off, .off, .off, .off,
                .night, .night, .night, .night, .off, .off, .off, .off
            ]
        case .monFri8h:
            return [.day, .day, .day, .day, .day, .off, .off]
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var use24HourTime: Bool = true
    var appearanceMode: AppearanceMode = .light
    var payPeriodCycle: PayPeriodCycle = .biweekly
    var employeeName: String = ""
    var currencySymbol: String = "$"
}

struct FlatShiftBackup: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var jobs: [JobProfile]
    var shifts: [ShiftEntry]
    var preferences: AppPreferences
}
