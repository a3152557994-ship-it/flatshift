import Foundation
import StoreKit
import SwiftUI
import UserNotifications

enum FlatShiftProductID {
    static let lifetime = "com.yanghe.flatshift.pro.lifetime"
    static let yearly = "com.yanghe.flatshift.pro.yearly"
    static let monthly = "com.yanghe.flatshift.pro.monthly"
    static let all: [String] = [lifetime, yearly, monthly]
}

@MainActor
final class StoreManager: ObservableObject {
    /// Plugged v1.0.1 free tier: 1 lifetime free PDF export total (never resets monthly),
    /// 1 job, and up to 2 weeks of Rotation Auto-Painter preview.
    static let freeLifetimePDFExportLimit = 1
    static let freeJobLimit = 1
    static let freeRotationMaxWeeks = 2

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var statusMessage: String?

    @Published private(set) var lifetimeFreePDFExportsUsed: Int = 0
    @Published private(set) var totalSuccessfulExports: Int = 0

    private let lifetimePDFCountKey = "flatshift.quota.lifetimePdfCount.v1"
    private let legacyTotalKey = "flatshift.total.exports"
    private let proCacheKey = "flatshift.pro.cached"

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?

    init(userDefaults: UserDefaults = .standard, startListeners: Bool = true) {
        self.defaults = userDefaults
        self.isPro = userDefaults.bool(forKey: proCacheKey)
        self.totalSuccessfulExports = userDefaults.integer(forKey: legacyTotalKey)

        // Migrate any existing 1.0.0 user who already exported PDFs so the lifetime cap is accurate.
        if userDefaults.object(forKey: lifetimePDFCountKey) != nil {
            self.lifetimeFreePDFExportsUsed = userDefaults.integer(forKey: lifetimePDFCountKey)
        } else {
            self.lifetimeFreePDFExportsUsed = self.totalSuccessfulExports
        }

        if startListeners {
            updatesTask = Task {
                await listenForTransactions()
            }
            Task {
                await loadProducts()
                await refreshEntitlements()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var remainingFreePDFExports: Int {
        max(0, Self.freeLifetimePDFExportLimit - lifetimeFreePDFExportsUsed)
    }

    var canExportFreePDF: Bool {
        isPro || remainingFreePDFExports > 0
    }

    func canPaintRotation(weeks: Int) -> Bool {
        isPro || weeks <= Self.freeRotationMaxWeeks
    }

    func recordPDFExport() {
        if !isPro {
            lifetimeFreePDFExportsUsed += 1
            defaults.set(lifetimeFreePDFExportsUsed, forKey: lifetimePDFCountKey)
        }
        totalSuccessfulExports += 1
        defaults.set(totalSuccessfulExports, forKey: legacyTotalKey)
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(for id: String) -> String {
        if let p = product(for: id) {
            return p.displayPrice
        }
        switch id {
        case FlatShiftProductID.lifetime:
            return L10n.t("$12.99", "¥48", "HK$78")
        case FlatShiftProductID.yearly:
            return L10n.t("$7.99", "¥28", "HK$48")
        case FlatShiftProductID.monthly:
            return L10n.t("$3.99", "¥12", "HK$18")
        default:
            return ""
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: FlatShiftProductID.all)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            // Fallback display prices stay visible offline
        }
    }

    func purchase(_ productId: String) async -> Bool {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        if products.isEmpty {
            await loadProducts()
        }
        guard let target = product(for: productId) else {
            statusMessage = L10n.t(
                "App Store products are syncing. Please check your connection and try again.",
                "苹果商店内购信息正在同步，请检查网络后重试。",
                "App Store 內購資訊正在同步，請檢查網路連線後重試。"
            )
            return false
        }

        do {
            let result = try await target.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    if productId == FlatShiftProductID.yearly {
                        scheduleTrialReminder()
                    }
                    FunnelMetrics.shared.record(.paywallConverted)
                    statusMessage = L10n.t(
                        "FlatShift Pro unlocked! Unlimited jobs, OT breakdown & exports enabled.",
                        "已解锁 FlatShift 永久/专业版！",
                        "已解鎖 FlatShift 專業版／永久買斷權益！"
                    )
                    return true
                case .unverified:
                    statusMessage = L10n.t(
                        "Purchase verification failed. Please retry.",
                        "交易校验未通过，请重试。",
                        "交易驗證未通過，請重試。"
                    )
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                statusMessage = L10n.t(
                    "Purchase is pending approval.",
                    "交易等待审批中。",
                    "交易等待核准中。"
                )
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = L10n.t(
                "Purchase failed: \(error.localizedDescription)",
                "购买未完成：\(error.localizedDescription)",
                "購買未完成：\(error.localizedDescription)"
            )
            return false
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isPro
                ? L10n.t(
                    "FlatShift Pro restored successfully!",
                    "已成功恢复 FlatShift Pro 权益！",
                    "已成功還原 FlatShift Pro 權益！"
                )
                : L10n.t(
                    "No active purchases found on this Apple Account.",
                    "当前苹果账号下未找到已购记录。",
                    "目前 Apple 帳號下找不到有效購買紀錄。"
                )
        } catch {
            statusMessage = L10n.t(
                "Restore failed. Please try again shortly.",
                "恢复购买失败，请稍后再试。",
                "還原購買失敗，請稍後再試。"
            )
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               FlatShiftProductID.all.contains(tx.productID),
               tx.revocationDate == nil {
                unlocked = true
                break
            }
        }
        isPro = unlocked
        defaults.set(unlocked, forKey: proCacheKey)
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let tx) = update {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }

    /// Day-5 honest reminder for the 7-day free trial (48h before Day-7 billing).
    static let trialReminderDelaySeconds: TimeInterval = 5 * 24 * 3600

    private func scheduleTrialReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = L10n.t(
                "FlatShift · Free Trial Ends in 2 Days",
                "FlatShift · 7 天免费试用还剩 2 天",
                "FlatShift · 7 天免費試用還剩 2 天"
            )
            content.body = L10n.t(
                "Day 5 reminder: Your 7-day free trial ends in 48 hours. Cancel anytime in iOS Settings > Apple Account > Subscriptions.",
                "第 5 天提醒：您的 7 天免费试用将在 48 小时后到期，如暂不需要可随时在系统「订阅」中一键取消。",
                "第 5 天提醒：您的 7 天免費試用將於 48 小時後到期，如暫不需要可隨時在系統「訂閱項目」中一鍵取消。"
            )
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Self.trialReminderDelaySeconds,
                repeats: false
            )
            let req = UNNotificationRequest(
                identifier: "flatshift.trial.reminder.day5",
                content: content,
                trigger: trigger
            )
            center.add(req)
        }
    }
}
