import Foundation

enum AppLanguage: String, Equatable, CaseIterable {
    case en
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
}

enum L10n {
    static var forcedLanguage: String? = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ui_lang"), idx + 1 < args.count {
            return args[idx + 1]
        }
        return nil
    }()

    static func resolveLanguage(from identifier: String) -> AppLanguage {
        let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        guard normalized.hasPrefix("zh") else { return .en }

        if normalized.contains("hant")
            || normalized == "zh-hk" || normalized.hasPrefix("zh-hk-")
            || normalized == "zh-tw" || normalized.hasPrefix("zh-tw-")
            || normalized == "zh-mo" || normalized.hasPrefix("zh-mo-")
            || normalized.hasSuffix("-hk")
            || normalized.hasSuffix("-tw")
            || normalized.hasSuffix("-mo") {
            return .zhHant
        }
        return .zhHans
    }

    static var currentLanguage: AppLanguage {
        if let forced = forcedLanguage {
            return resolveLanguage(from: forced)
        }
        let pref = Locale.preferredLanguages.first ?? "en"
        return resolveLanguage(from: pref)
    }

    static var isChinese: Bool {
        currentLanguage != .en
    }

    static var isTraditionalChinese: Bool {
        currentLanguage == .zhHant
    }

    /// Backward-compatible 2-arg helper (EN + Simplified/fallback Chinese).
    static func t(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    /// 3-arg helper with authentic Hong Kong / Taiwan Traditional Chinese copy.
    static func t(_ en: String, _ zhHans: String, _ zhHant: String) -> String {
        switch currentLanguage {
        case .en: return en
        case .zhHans: return zhHans
        case .zhHant: return zhHant
        }
    }

    static var locale: Locale {
        switch currentLanguage {
        case .en:
            return Locale(identifier: "en_US")
        case .zhHans:
            return Locale(identifier: "zh_Hans_CN")
        case .zhHant:
            let region = Locale.current.region?.identifier.uppercased()
            if region == "HK" || region == "MO" {
                return Locale(identifier: "zh_Hant_HK")
            }
            return Locale(identifier: "zh_Hant_TW")
        }
    }
}
