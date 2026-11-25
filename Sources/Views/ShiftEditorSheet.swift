import SwiftUI

struct ShiftEditorSheet: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ShiftEntry
    let isNew: Bool
    var onSaved: ((ShiftEntry) -> Void)? = nil

    @State private var useCustomRate: Bool
    @State private var customRateText: String

    init(shift: ShiftEntry, isNew: Bool, onSaved: ((ShiftEntry) -> Void)? = nil) {
        _draft = State(initialValue: shift)
        self.isNew = isNew
        self.onSaved = onSaved
        _useCustomRate = State(initialValue: shift.customHourlyRate != nil)
        _customRateText = State(initialValue: shift.customHourlyRate.map { String(format: "%.2f", $0) } ?? "")
    }

    private var selectedJob: JobProfile? {
        shiftStore.job(for: draft.jobId) ?? shiftStore.jobs.first
    }

    private var liveBreakdown: ShiftPayBreakdown? {
        guard let job = selectedJob else { return nil }
        var previewShift = draft
        if useCustomRate, let parsed = Double(customRateText), parsed > 0 {
            previewShift.customHourlyRate = parsed
        } else {
            previewShift.customHourlyRate = nil
        }
        let sum = PayEngine.summarize(
            shifts: [previewShift],
            jobs: [job],
            periodStart: previewShift.startDate.addingTimeInterval(-3600),
            periodEnd: previewShift.startDate.addingTimeInterval(3600 * 36)
        )
        return sum.breakdowns.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Job & Shift Type", "工作与班次类型")) {
                    Picker(L10n.t("Job", "所属工作"), selection: $draft.jobId) {
                        ForEach(shiftStore.jobs) { job in
                            Text(job.name).tag(job.id)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ShiftType.allCases) { st in
                                let active = draft.shiftType == st
                                Button {
                                    draft.shiftType = st
                                    if st == .night {
                                        draft.applyNightDiff = true
                                    } else if st == .day || st == .off {
                                        draft.applyNightDiff = false
                                    }
                                    if st == .off {
                                        draft.unpaidBreakMinutes = 0
                                    } else if draft.endDate <= draft.startDate {
                                        draft.endDate = draft.startDate.addingTimeInterval(12.5 * 3600)
                                        draft.unpaidBreakMinutes = selectedJob?.defaultUnpaidBreakMinutes ?? 30
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: st.iconName)
                                            .font(.caption)
                                        Text(st.shortBadge)
                                            .font(.caption.weight(.bold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(active ? st.color : ShiftTheme.cardElevated)
                                    .foregroundStyle(active ? .white : ShiftTheme.ink)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if draft.shiftType.isPayable {
                    Section(L10n.t("Hours & Unpaid Break", "上下班时间与扣休")) {
                        DatePicker(
                            L10n.t("Clock In", "上班时间"),
                            selection: $draft.startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .onChange(of: draft.startDate) { _, newVal in
                            if draft.endDate <= newVal {
                                draft.endDate = newVal.addingTimeInterval(8.5 * 3600)
                            }
                            draft.applyWeekendDiff = PayEngine.isWeekend(newVal)
                        }

                        DatePicker(
                            L10n.t("Clock Out", "下班时间"),
                            selection: $draft.endDate,
                            in: draft.startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Stepper(
                            value: $draft.unpaidBreakMinutes,
                            in: 0...180,
                            step: 15
                        ) {
                            HStack {
                                Text(L10n.t("Unpaid Break", "无薪休息扣除"))
                                Spacer()
                                Text("\(draft.unpaidBreakMinutes) \(L10n.t("min", "分钟"))")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(ShiftTheme.muted)
                            }
                        }

                        HStack(spacing: 8) {
                            Text(L10n.t("Quick Length:", "快捷时长："))
                                .font(.caption)
                                .foregroundStyle(ShiftTheme.muted)
                            ForEach([8.0, 10.0, 12.0], id: \.self) { hrs in
                                Button("\(Int(hrs))h") {
                                    let totalMins = Int(hrs * 60) + draft.unpaidBreakMinutes
                                    draft.endDate = draft.startDate.addingTimeInterval(Double(totalMins * 60))
                                }
                                .font(.caption.weight(.bold).monospacedDigit())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ShiftTheme.cobaltSoft)
                                .foregroundStyle(ShiftTheme.cobalt)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Section(L10n.t("Differentials & Bonuses", "津贴与倍率加成")) {
                        Toggle(isOn: $draft.applyNightDiff) {
                            HStack {
                                Image(systemName: "moon.stars.fill").foregroundStyle(ShiftTheme.nightViolet)
                                Text(L10n.t("Night Differential", "夜班津贴"))
                                if let j = selectedJob, j.nightDifferentialPerHour > 0 {
                                    Text("(+\(PayEngine.formatMoney(j.nightDifferentialPerHour, symbol: j.currencySymbol))/hr)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(ShiftTheme.muted)
                                }
                            }
                        }
                        Toggle(isOn: $draft.applyWeekendDiff) {
                            HStack {
                                Image(systemName: "calendar.badge.plus").foregroundStyle(ShiftTheme.swingTeal)
                                Text(L10n.t("Weekend Differential", "周末津贴"))
                                if let j = selectedJob, j.weekendDifferentialPerHour > 0 {
                                    Text("(+\(PayEngine.formatMoney(j.weekendDifferentialPerHour, symbol: j.currencySymbol))/hr)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(ShiftTheme.muted)
                                }
                            }
                        }
                        Toggle(isOn: $draft.isHoliday) {
                            HStack {
                                Image(systemName: "star.fill").foregroundStyle(ShiftTheme.overtimeAmber)
                                Text(L10n.t("Holiday Multiplier", "法定节假日倍率"))
                                if let j = selectedJob {
                                    Text("(\(String(format: "%.1fx", j.holidayMultiplier)))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(ShiftTheme.muted)
                                }
                            }
                        }

                        Toggle(L10n.t("Custom Hourly Rate Override", "本次班次临时调整时薪"), isOn: $useCustomRate)
                        if useCustomRate {
                            HStack {
                                Text(selectedJob?.currencySymbol ?? "$")
                                TextField(L10n.t("Hourly rate", "输入时薪"), text: $customRateText)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                }

                Section(L10n.t("Notes", "备注")) {
                    TextField(L10n.t("Ward, job site, or handoff notes...", "填写科室、工地或交接班备注..."), text: $draft.notes)
                }

                if let b = liveBreakdown, draft.shiftType.isPayable {
                    Section(L10n.t("Live Pay Calculation Preview", "实时薪资估算")) {
                        HStack {
                            Text(L10n.t("Paid Hours", "计薪工时"))
                            Spacer()
                            Text("\(PayEngine.formatHoursDecimal(b.totalHours))h (Reg \(PayEngine.formatHoursDecimal(b.regularHours)) / OT \(PayEngine.formatHoursDecimal(b.totalOTHours)))")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        if b.differentialPay > 0 {
                            HStack {
                                Text(L10n.t("Differential Bonus", "夜班/周末津贴"))
                                Spacer()
                                Text("+" + PayEngine.formatMoney(b.differentialPay, symbol: b.job.currencySymbol))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(ShiftTheme.cobalt)
                            }
                        }
                        HStack {
                            Text(L10n.t("Shift Gross Pay", "本班税前应发"))
                            Spacer()
                            Text(PayEngine.formatMoney(b.grossPay, symbol: b.job.currencySymbol))
                                .font(.headline.weight(.bold).monospacedDigit())
                        }
                        HStack {
                            Text(L10n.t("Est. Net Take-Home", "预估税后到手"))
                            Spacer()
                            Text(PayEngine.formatMoney(b.estimatedNetPay, symbol: b.job.currencySymbol))
                                .font(.headline.weight(.heavy).monospacedDigit())
                                .foregroundStyle(ShiftTheme.shiftMint)
                        }
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            shiftStore.deleteShift(draft)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Label(L10n.t("Delete Shift", "删除此班次"), systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? L10n.t("Add Shift", "新增班次") : L10n.t("Edit Shift", "编辑班次"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "保存")) {
                        if useCustomRate, let parsed = Double(customRateText), parsed > 0 {
                            draft.customHourlyRate = parsed
                        } else {
                            draft.customHourlyRate = nil
                        }
                        shiftStore.upsertShift(draft)
                        onSaved?(draft)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
