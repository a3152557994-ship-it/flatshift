import SwiftUI
import UniformTypeIdentifiers

struct JobsSettingsView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager

    var onOpenPaywall: (String?) -> Void

    @State private var editingJob: JobProfile? = nil
    @State private var isNewJob: Bool = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var showImporter: Bool = false
    @State private var feedbackText: String? = nil

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/terms.html")!
    private let supportURL = URL(string: "https://a3152557994-ship-it.github.io/flatshift/support.html")!

    private struct CrossPromoApp: Identifiable {
        let id: String
        let name: String
        let tagline: String
        let icon: String
        let color: Color
        let url: URL
    }

    private var siblingTools: [CrossPromoApp] {
        [
            CrossPromoApp(
                id: "flatbill",
                name: "FlatBill",
                tagline: L10n.t("Offline PDF Invoice & Estimate Maker", "纯离线 PDF 发票与报价单工具", "純離線 PDF 發票與報價單工具"),
                icon: "doc.text.fill",
                color: ShiftTheme.cobalt,
                url: URL(string: "https://apps.apple.com/app/id6839021639")!
            ),
            CrossPromoApp(
                id: "miledeck",
                name: "MileDeck",
                tagline: L10n.t("Offline Mileage & Tax Deduction Tracker", "纯离线里程记录与税务抵扣账本", "純離線里程紀錄與報稅抵扣工具"),
                icon: "car.fill",
                color: ShiftTheme.shiftMint,
                url: URL(string: "https://apps.apple.com/app/id6839022103")!
            ),
            CrossPromoApp(
                id: "purescan",
                name: "PureScan",
                tagline: L10n.t("Zero-Cloud Document & Receipt Scanner", "无云端文档与收据高清扫描仪", "無雲端文件與收據高清掃描工具"),
                icon: "doc.viewfinder.fill",
                color: ShiftTheme.nightViolet,
                url: URL(string: "https://apps.apple.com/app/id6837347918")!
            ),
            CrossPromoApp(
                id: "cleanshield",
                name: "CleanShield",
                tagline: L10n.t("Private Photo & Storage Cleaner", "本地私密相册整理与瘦身工具", "本機私密相簿整理與空間清理"),
                icon: "sparkles.rectangle.stack.fill",
                color: ShiftTheme.swingTeal,
                url: URL(string: "https://apps.apple.com/app/id6836843272")!
            ),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Pro Lifetime Banner
                Section {
                    if store.isPro {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(ShiftTheme.shiftMint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("FlatShift Pro Active", "FlatShift Pro 已解锁", "FlatShift Pro 已解鎖"))
                                    .font(.headline.weight(.bold))
                                Text(L10n.t("Unlimited jobs, detailed OT & net breakdown, 52w rotations & unlimited clean PDF/CSV exports.", "已解锁无限工作数、完整加班与税后明细、全年排班及无限导出。", "已解鎖無限份工作、完整加班費試算與實領明細、全年排班與無限匯出。"))
                                    .font(.caption)
                                    .foregroundStyle(ShiftTheme.muted)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            onOpenPaywall(nil)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "seal.fill")
                                    .font(.title2)
                                    .foregroundStyle(ShiftTheme.overtimeAmber)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(
                                        L10n.t(
                                            "Unlock Lifetime Pro — \(store.displayPrice(for: FlatShiftProductID.lifetime)) Once",
                                            "买断永久版 — 仅需 \(store.displayPrice(for: FlatShiftProductID.lifetime)) 一次",
                                            "永久買斷版 — 一次付清 \(store.displayPrice(for: FlatShiftProductID.lifetime))"
                                        )
                                    )
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(.white)
                                    Text(
                                        L10n.t(
                                            "Or try 7 days free · Full OT breakdown, 52w rotations & unlimited PDFs",
                                            "也支持 7 天免费试用 · 解锁完整加班明细、全年排班与无限 PDF",
                                            "亦支援 7 天免費試用 · 解鎖加班費試算、全年更表與無限 PDF"
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.78))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ShiftTheme.overtimeAmber)
                            }
                            .padding(14)
                            .background(ShiftTheme.midnightIndigo)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                }

                if let feedbackText {
                    Section {
                        Text(feedbackText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ShiftTheme.shiftMint)
                    }
                }

                // MARK: - Jobs & Pay Rules
                Section {
                    ForEach(shiftStore.jobs) { job in
                        Button {
                            isNewJob = false
                            editingJob = job
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(job.swatchColor)
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(job.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(ShiftTheme.ink)
                                    Text(job.ruleSummary)
                                        .font(.caption2)
                                        .foregroundStyle(ShiftTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(PayEngine.formatMoney(job.hourlyRate, symbol: job.currencySymbol))/hr")
                                        .font(.subheadline.weight(.heavy).monospacedDigit())
                                        .foregroundStyle(ShiftTheme.ink)
                                    Text(L10n.t("Tax \(Int(job.estimatedTaxRatePercent))%", "扣税 \(Int(job.estimatedTaxRatePercent))%", "稅率 \(Int(job.estimatedTaxRatePercent))%"))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(ShiftTheme.muted)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }

                    Button {
                        if !store.isPro && shiftStore.jobs.count >= StoreManager.freeJobLimit {
                            let price = store.displayPrice(for: FlatShiftProductID.lifetime)
                            onOpenPaywall(
                                L10n.t(
                                    "Free plan includes 1 job. Unlock FlatShift Pro (7-day free trial or \(price) lifetime) to track unlimited jobs & side gigs.",
                                    "免费版支持 1 份工作，升级 FlatShift Pro（含 7 天免费试用或 \(price) 永久买断）即可管理无限多份工作与兼职。",
                                    "免費版支援 1 份工作，升級 FlatShift Pro（含 7 天免費試用或 \(price) 永久買斷）即可管理無限份工作與兼職。"
                                )
                            )
                        } else {
                            isNewJob = true
                            editingJob = JobProfile(
                                name: "",
                                role: "",
                                colorHex: "#2563EB",
                                hourlyRate: L10n.currentLanguage == .zhHant ? 180.0 : (L10n.isChinese ? 50.0 : 35.0),
                                defaultUnpaidBreakMinutes: 30,
                                dailyOTThresholdHours: 8.0,
                                dailyOTMultiplier: 1.5,
                                dailyDoubleTimeThresholdHours: 12.0,
                                dailyDoubleTimeMultiplier: 2.0,
                                weeklyOTThresholdHours: 40.0,
                                weeklyOTMultiplier: 1.5,
                                nightDifferentialPerHour: L10n.currentLanguage == .zhHant ? 30.0 : (L10n.isChinese ? 10.0 : 4.0),
                                weekendDifferentialPerHour: L10n.currentLanguage == .zhHant ? 20.0 : (L10n.isChinese ? 6.0 : 2.5),
                                holidayMultiplier: 2.0,
                                estimatedTaxRatePercent: L10n.isChinese ? 10.0 : 20.0,
                                currencySymbol: shiftStore.preferences.currencySymbol
                            )
                        }
                    } label: {
                        HStack {
                            Label(L10n.t("Add New Job / Side Gig", "新增工作 / 副业时薪配置", "新增工作 / 兼職時薪設定"), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(ShiftTheme.cobalt)
                            Spacer()
                            if !store.isPro && shiftStore.jobs.count >= StoreManager.freeJobLimit {
                                Text("PRO")
                                    .font(.system(size: 10, weight: .black))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(ShiftTheme.overtimeAmber)
                                    .foregroundStyle(ShiftTheme.midnightIndigo)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } header: {
                    Text(L10n.t("Jobs, Overtime & Differentials", "工作、加班倍率与夜班津贴", "工作、加班費倍率與夜班津貼"))
                }

                // MARK: - Display & Shift Preferences
                Section(L10n.t("Display & Shift Preferences", "显示与排班偏好", "顯示與更表偏好")) {
                    Picker(L10n.t("Theme Mode", "界面主题", "介面主題"), selection: Binding(
                        get: { shiftStore.preferences.appearanceMode },
                        set: {
                            shiftStore.preferences.appearanceMode = $0
                            shiftStore.save()
                        }
                    )) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: Binding(
                        get: { shiftStore.preferences.use24HourTime },
                        set: {
                            shiftStore.preferences.use24HourTime = $0
                            shiftStore.save()
                        }
                    )) {
                        Label(L10n.t("24-Hour Military Time (19:00–07:30)", "24小时制时间显示（19:00–07:30）", "24小時制時間顯示（19:00–07:30）"), systemImage: "clock.fill")
                    }

                    Picker(L10n.t("Pay Period Cycle", "默认计薪周期", "預設發薪週期"), selection: Binding(
                        get: { shiftStore.preferences.payPeriodCycle },
                        set: {
                            shiftStore.preferences.payPeriodCycle = $0
                            shiftStore.save()
                        }
                    )) {
                        ForEach(PayPeriodCycle.allCases) { cycle in
                            Text(cycle.title).tag(cycle)
                        }
                    }

                    HStack {
                        Text(L10n.t("Name on PDF & Schedule", "工资单与排班表姓名", "薪資單與更表姓名"))
                        TextField(L10n.t("Your Name", "填写姓名", "輸入姓名"), text: Binding(
                            get: { shiftStore.preferences.employeeName },
                            set: {
                                shiftStore.preferences.employeeName = $0
                                shiftStore.save()
                            }
                        ))
                        .multilineTextAlignment(.trailing)
                    }
                }

                // MARK: - Local Backup & Restore
                Section(L10n.t("Offline Data & Backup", "本地数据与离线备份", "本機資料與離線備份")) {
                    Button {
                        exportJSONBackup()
                    } label: {
                        Label(L10n.t("Export Full Local Backup (JSON)", "导出本地全量备份 (JSON)", "匯出本機完整備份 (JSON)"), systemImage: "externaldrive.badge.checkmark")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label(L10n.t("Restore from JSON Backup", "从 JSON 备份恢复数据", "從 JSON 備份還原資料"), systemImage: "arrow.down.doc")
                    }

                    Button {
                        shiftStore.seedRealisticStarterData()
                        showFeedback(L10n.t("Starter sample jobs & shifts reloaded.", "已重新载入示例工作与班次数据。", "已重新載入範例工作與更表資料。"))
                    } label: {
                        Label(L10n.t("Reset to Sample Data", "恢复内置演示数据", "重設為範例資料"), systemImage: "arrow.counterclockwise")
                            .foregroundStyle(ShiftTheme.muted)
                    }
                }

                // MARK: - Cross-Promotion: More Zero-Subscription Offline Tools
                Section(
                    L10n.t(
                        "More Zero-Subscription Offline Tools",
                        "更多无广告买断制离线工具",
                        "更多免訂閱離線效率工具"
                    )
                ) {
                    ForEach(siblingTools) { app in
                        Link(destination: app.url) {
                            HStack(spacing: 12) {
                                Image(systemName: app.icon)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(app.color)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(ShiftTheme.ink)
                                    Text(app.tagline)
                                        .font(.caption2)
                                        .foregroundStyle(ShiftTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .foregroundStyle(ShiftTheme.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // MARK: - Purchases & Legal
                Section(L10n.t("Purchases & Legal", "购买与隐私说明", "購買與私隱條款")) {
                    Button {
                        Task {
                            await store.restorePurchases()
                            if let msg = store.statusMessage {
                                showFeedback(msg)
                            }
                        }
                    } label: {
                        Label(L10n.t("Restore Purchases", "恢复购买", "還原購買"), systemImage: "arrow.clockwise.circle")
                    }

                    Link(destination: privacyURL) {
                        Label(L10n.t("Privacy Policy", "隐私政策", "私隱政策"), systemImage: "hand.raised.fill")
                    }
                    Link(destination: termsURL) {
                        Label(L10n.t("Terms of Use (EULA)", "使用条款 (EULA)", "使用條款 (EULA)"), systemImage: "doc.plaintext")
                    }
                    Link(destination: supportURL) {
                        Label(L10n.t("Support & FAQ", "技术支持与常见问题", "技術支援與常見問題"), systemImage: "questionmark.circle")
                    }

                    HStack {
                        Text(L10n.t("Version", "版本", "版本"))
                        Spacer()
                        Text("1.0.1 · 100% Offline")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ShiftTheme.muted)
                    }
                }
            }
            .navigationTitle(L10n.t("Jobs & Settings", "工作与设置", "工作與設定"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingJob) { target in
                JobEditorSheet(job: target, isNew: isNewJob) {
                    showFeedback(L10n.t("Job pay rules saved.", "工作薪资规则已保存。", "工作薪資規則已儲存。"))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ActivityShareSheet(items: [url])
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let secured = url.startAccessingSecurityScopedResource()
                    defer { if secured { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        let restoredCount = try shiftStore.importBackupJSONData(data)
                        showFeedback(L10n.t("Restored \(restoredCount) shifts from backup!", "已成功恢复 \(restoredCount) 条班次记录！", "已成功還原 \(restoredCount) 筆更表資料！"))
                    } catch {
                        showFeedback(L10n.t("Import failed: \(error.localizedDescription)", "恢复失败：\(error.localizedDescription)", "還原失敗：\(error.localizedDescription)"))
                    }
                case .failure(let err):
                    showFeedback(err.localizedDescription)
                }
            }
        }
    }

    private func exportJSONBackup() {
        do {
            let data = try shiftStore.exportBackupJSONData()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("FlatShift_Backup_\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: url, options: .atomic)
            shareURL = url
            showShareSheet = true
        } catch {
            showFeedback(L10n.t("Backup export failed.", "导出备份失败。", "匯出備份失敗。"))
        }
    }

    private func showFeedback(_ msg: String) {
        feedbackText = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if feedbackText == msg { feedbackText = nil }
        }
    }
}

struct JobEditorSheet: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: JobProfile
    let isNew: Bool
    var onSaved: (() -> Void)? = nil

    private let colorChoices = ["#2563EB", "#10B981", "#7C3AED", "#F59E0B", "#0D9488", "#E11D48"]
    private let currencies = ["$", "HK$", "NT$", "¥", "€", "£"]

    init(job: JobProfile, isNew: Bool, onSaved: (() -> Void)? = nil) {
        _draft = State(initialValue: job)
        self.isNew = isNew
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Job Profile", "工作基本信息", "工作基本資料")) {
                    TextField(L10n.t("Job Name (e.g., Mercy Hospital RN)", "工作名称（例如：急诊科12h倒班）", "工作名稱（例如：急症室12h輪班）"), text: $draft.name)
                    TextField(L10n.t("Role / Department", "岗位 / 部门", "職位 / 部門"), text: $draft.role)

                    Picker(L10n.t("Currency", "货币符号", "貨幣符號"), selection: $draft.currencySymbol) {
                        ForEach(currencies, id: \.self) { c in Text(c).tag(c) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        Text(L10n.t("Badge Color", "标签颜色", "標籤顏色"))
                        Spacer()
                        ForEach(colorChoices, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(ShiftTheme.ink, lineWidth: draft.colorHex == hex ? 2.5 : 0)
                                )
                                .onTapGesture { draft.colorHex = hex }
                        }
                    }
                }

                Section(L10n.t("Base Rate & Unpaid Break", "基础时薪与默认扣休", "基本時薪與預設無薪休息")) {
                    HStack {
                        Text(L10n.t("Hourly Rate (\(draft.currencySymbol))", "基础时薪 (\(draft.currencySymbol))", "基本時薪 (\(draft.currencySymbol))"))
                        Spacer()
                        TextField("44.00", value: $draft.hourlyRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Stepper(value: $draft.defaultUnpaidBreakMinutes, in: 0...120, step: 15) {
                        HStack {
                            Text(L10n.t("Default Unpaid Break", "默认无薪休息", "預設無薪休息"))
                            Spacer()
                            Text("\(draft.defaultUnpaidBreakMinutes)m")
                                .foregroundStyle(ShiftTheme.muted)
                        }
                    }
                }

                Section(L10n.t("Overtime Rules (0 = Off)", "加班算薪规则（填 0 表示关闭）", "加班費試算規則（填 0 為關閉）")) {
                    numberRow(L10n.t("Daily OT After (hrs)", "单日加班起算 (小时)", "單日加班起算 (小時)"), value: $draft.dailyOTThresholdHours)
                    numberRow(L10n.t("Daily OT Multiplier", "单日加班倍率 (如 1.5)", "單日加班倍率 (如 1.5)"), value: $draft.dailyOTMultiplier)
                    numberRow(L10n.t("Daily Double-Time After (hrs)", "单日双倍起算 (小时)", "單日雙倍起算 (小時)"), value: $draft.dailyDoubleTimeThresholdHours)
                    numberRow(L10n.t("Double-Time Multiplier", "双倍加班倍率 (如 2.0)", "雙倍加班倍率 (如 2.0)"), value: $draft.dailyDoubleTimeMultiplier)
                    numberRow(L10n.t("Weekly OT After (hrs/wk)", "单周加班起算 (小时/周)", "單週加班起算 (小時/週)"), value: $draft.weeklyOTThresholdHours)
                    numberRow(L10n.t("Weekly OT Multiplier", "单周加班倍率", "單週加班倍率"), value: $draft.weeklyOTMultiplier)
                }

                Section(L10n.t("Shift Differentials & Tax Estimate", "夜班/周末津贴与预估扣税", "夜班津貼與預估扣稅")) {
                    numberRow(L10n.t("Night Diff (+\(draft.currencySymbol)/hr)", "夜班津贴 (+\(draft.currencySymbol)/时)", "夜班津貼 (+\(draft.currencySymbol)/時)"), value: $draft.nightDifferentialPerHour)
                    numberRow(L10n.t("Weekend Diff (+\(draft.currencySymbol)/hr)", "周末津贴 (+\(draft.currencySymbol)/时)", "週末津貼 (+\(draft.currencySymbol)/時)"), value: $draft.weekendDifferentialPerHour)
                    numberRow(L10n.t("Holiday Multiplier", "节假日倍率 (如 2.0)", "公眾假期倍率 (如 2.0)"), value: $draft.holidayMultiplier)
                    numberRow(L10n.t("Est. Tax Withholding (%)", "预估税费社保比例 (%)", "預估稅金比例 (%)"), value: $draft.estimatedTaxRatePercent)
                }

                if !isNew && shiftStore.jobs.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            shiftStore.deleteJob(draft)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label(L10n.t("Delete Job & Its Shifts", "删除此工作及关联班次", "刪除此工作與相關更表"), systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? L10n.t("New Job", "新增工作", "新增工作") : L10n.t("Edit Job Rules", "编辑薪资规则", "編輯薪資規則"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "保存", "儲存")) {
                        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draft.name = L10n.t("My Shift Job", "我的主工作", "我的主要工作")
                        }
                        shiftStore.upsertJob(draft)
                        onSaved?()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func numberRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }
}
