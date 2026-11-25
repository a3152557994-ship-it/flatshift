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
                                Text(L10n.t("FlatShift Pro Active", "FlatShift Pro 已解锁"))
                                    .font(.headline.weight(.bold))
                                Text(L10n.t("Unlimited jobs, PDF timesheets, CSV exports & offline backups.", "已解锁无限工作数、无限 PDF 工资单与 CSV 导出。"))
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
                                    Text(L10n.t("Unlock Lifetime Pro — \(store.displayPrice(for: FlatShiftProductID.lifetime)) Once", "买断永久版 — 仅需 \(store.displayPrice(for: FlatShiftProductID.lifetime)) 一次"))
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundStyle(.white)
                                    Text(L10n.t("Pay once, own forever · Skip $30–$50 shift apps", "一次付清终身用 · 拒绝高价年费与广告"))
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
                                    Text(L10n.t("Tax \(Int(job.estimatedTaxRatePercent))%", "扣税 \(Int(job.estimatedTaxRatePercent))%"))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(ShiftTheme.muted)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }

                    Button {
                        if !store.isPro && shiftStore.jobs.count >= StoreManager.freeJobLimit {
                            onOpenPaywall(L10n.t(
                                "Free plan includes 1 custom job. Unlock FlatShift Pro ($9.99 once) to track unlimited jobs & side gigs.",
                                "免费版支持 1 份主工作，解锁 FlatShift Pro 即可管理无限多份工作与兼职副业。"
                            ))
                        } else {
                            isNewJob = true
                            editingJob = JobProfile(
                                name: "",
                                role: "",
                                colorHex: "#2563EB",
                                hourlyRate: L10n.isChinese ? 50.0 : 35.0,
                                defaultUnpaidBreakMinutes: 30,
                                dailyOTThresholdHours: 8.0,
                                dailyOTMultiplier: 1.5,
                                dailyDoubleTimeThresholdHours: 12.0,
                                dailyDoubleTimeMultiplier: 2.0,
                                weeklyOTThresholdHours: 40.0,
                                weeklyOTMultiplier: 1.5,
                                nightDifferentialPerHour: L10n.isChinese ? 10.0 : 4.0,
                                weekendDifferentialPerHour: L10n.isChinese ? 6.0 : 2.5,
                                holidayMultiplier: 2.0,
                                estimatedTaxRatePercent: L10n.isChinese ? 10.0 : 20.0,
                                currencySymbol: shiftStore.preferences.currencySymbol
                            )
                        }
                    } label: {
                        Label(L10n.t("Add New Job / Side Gig", "新增工作 / 副业时薪配置"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(ShiftTheme.cobalt)
                    }
                } header: {
                    Text(L10n.t("Jobs, Overtime & Differentials", "工作、加班倍率与夜班津贴"))
                }

                // MARK: - Display & Shift Preferences
                Section(L10n.t("Display & Shift Preferences", "显示与排班偏好")) {
                    Picker(L10n.t("Theme Mode", "界面主题"), selection: Binding(
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
                        Label(L10n.t("24-Hour Military Time (19:00–07:30)", "24小时制时间显示（19:00–07:30）"), systemImage: "clock.fill")
                    }

                    Picker(L10n.t("Pay Period Cycle", "默认计薪周期"), selection: Binding(
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
                        Text(L10n.t("Name on PDF", "工资单姓名"))
                        TextField(L10n.t("Your Name", "填写姓名"), text: Binding(
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
                Section(L10n.t("Offline Data & Backup", "本地数据与离线备份")) {
                    Button {
                        exportJSONBackup()
                    } label: {
                        Label(L10n.t("Export Full Local Backup (JSON)", "导出本地全量备份 (JSON)"), systemImage: "externaldrive.badge.checkmark")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label(L10n.t("Restore from JSON Backup", "从 JSON 备份恢复数据"), systemImage: "arrow.down.doc")
                    }

                    Button {
                        shiftStore.seedRealisticStarterData()
                        showFeedback(L10n.t("Starter sample jobs & shifts reloaded.", "已重新载入示例工作与班次数据。"))
                    } label: {
                        Label(L10n.t("Reset to Sample Data", "恢复内置演示数据"), systemImage: "arrow.counterclockwise")
                            .foregroundStyle(ShiftTheme.muted)
                    }
                }

                // MARK: - Purchases & Legal
                Section(L10n.t("Purchases & Legal", "购买与隐私说明")) {
                    Button {
                        Task {
                            await store.restorePurchases()
                            if let msg = store.statusMessage {
                                showFeedback(msg)
                            }
                        }
                    } label: {
                        Label(L10n.t("Restore Purchases", "恢复购买"), systemImage: "arrow.clockwise.circle")
                    }

                    Link(destination: privacyURL) {
                        Label(L10n.t("Privacy Policy", "隐私政策"), systemImage: "hand.raised.fill")
                    }
                    Link(destination: termsURL) {
                        Label(L10n.t("Terms of Use (EULA)", "使用条款 (EULA)"), systemImage: "doc.plaintext")
                    }
                    Link(destination: supportURL) {
                        Label(L10n.t("Support & FAQ", "技术支持与常见问题"), systemImage: "questionmark.circle")
                    }

                    HStack {
                        Text(L10n.t("Version", "版本"))
                        Spacer()
                        Text("1.0.0 · 100% Offline")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ShiftTheme.muted)
                    }
                }
            }
            .navigationTitle(L10n.t("Jobs & Settings", "工作与设置"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingJob) { target in
                JobEditorSheet(job: target, isNew: isNewJob) {
                    showFeedback(L10n.t("Job pay rules saved.", "工作薪资规则已保存。"))
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
                        showFeedback(L10n.t("Restored \(restoredCount) shifts from backup!", "已成功恢复 \(restoredCount) 条班次记录！"))
                    } catch {
                        showFeedback(L10n.t("Import failed: \(error.localizedDescription)", "恢复失败：\(error.localizedDescription)"))
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
            showFeedback(L10n.t("Backup export failed.", "导出备份失败。"))
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
    private let currencies = ["$", "¥", "€", "£"]

    init(job: JobProfile, isNew: Bool, onSaved: (() -> Void)? = nil) {
        _draft = State(initialValue: job)
        self.isNew = isNew
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Job Profile", "工作基本信息")) {
                    TextField(L10n.t("Job Name (e.g., Mercy Hospital RN)", "工作名称（例如：急诊科12h倒班）"), text: $draft.name)
                    TextField(L10n.t("Role / Department", "岗位 / 部门"), text: $draft.role)

                    Picker(L10n.t("Currency", "货币符号"), selection: $draft.currencySymbol) {
                        ForEach(currencies, id: \.self) { c in Text(c).tag(c) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 10) {
                        Text(L10n.t("Badge Color", "标签颜色"))
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

                Section(L10n.t("Base Rate & Unpaid Break", "基础时薪与默认扣休")) {
                    HStack {
                        Text(L10n.t("Hourly Rate (\(draft.currencySymbol))", "基础时薪 (\(draft.currencySymbol))"))
                        Spacer()
                        TextField("44.00", value: $draft.hourlyRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Stepper(value: $draft.defaultUnpaidBreakMinutes, in: 0...120, step: 15) {
                        HStack {
                            Text(L10n.t("Default Unpaid Break", "默认无薪休息"))
                            Spacer()
                            Text("\(draft.defaultUnpaidBreakMinutes)m")
                                .foregroundStyle(ShiftTheme.muted)
                        }
                    }
                }

                Section(L10n.t("Overtime Rules (0 = Off)", "加班算薪规则（填 0 表示关闭）")) {
                    numberRow(L10n.t("Daily OT After (hrs)", "单日加班起算 (小时)"), value: $draft.dailyOTThresholdHours)
                    numberRow(L10n.t("Daily OT Multiplier", "单日加班倍率 (如 1.5)"), value: $draft.dailyOTMultiplier)
                    numberRow(L10n.t("Daily Double-Time After (hrs)", "单日双倍起算 (小时)"), value: $draft.dailyDoubleTimeThresholdHours)
                    numberRow(L10n.t("Double-Time Multiplier", "双倍加班倍率 (如 2.0)"), value: $draft.dailyDoubleTimeMultiplier)
                    numberRow(L10n.t("Weekly OT After (hrs/wk)", "单周加班起算 (小时/周)"), value: $draft.weeklyOTThresholdHours)
                    numberRow(L10n.t("Weekly OT Multiplier", "单周加班倍率"), value: $draft.weeklyOTMultiplier)
                }

                Section(L10n.t("Shift Differentials & Tax Estimate", "夜班/周末津贴与预估扣税")) {
                    numberRow(L10n.t("Night Diff (+\(draft.currencySymbol)/hr)", "夜班津贴 (+\(draft.currencySymbol)/时)"), value: $draft.nightDifferentialPerHour)
                    numberRow(L10n.t("Weekend Diff (+\(draft.currencySymbol)/hr)", "周末津贴 (+\(draft.currencySymbol)/时)"), value: $draft.weekendDifferentialPerHour)
                    numberRow(L10n.t("Holiday Multiplier", "节假日倍率 (如 2.0)"), value: $draft.holidayMultiplier)
                    numberRow(L10n.t("Est. Tax Withholding (%)", "预估税费社保比例 (%)"), value: $draft.estimatedTaxRatePercent)
                }

                if !isNew && shiftStore.jobs.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            shiftStore.deleteJob(draft)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label(L10n.t("Delete Job & Its Shifts", "删除此工作及关联班次"), systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? L10n.t("New Job", "新增工作") : L10n.t("Edit Job Rules", "编辑薪资规则"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "保存")) {
                        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draft.name = L10n.t("My Shift Job", "我的主工作")
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
