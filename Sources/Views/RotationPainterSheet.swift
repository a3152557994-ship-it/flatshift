import SwiftUI

struct RotationPainterSheet: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var onApplied: ((Int) -> Void)? = nil
    var onRequestPaywall: ((String) -> Void)? = nil

    @State private var selectedPattern: RotationPattern = .nurse3x12
    @State private var selectedJobId: UUID? = nil
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var weeks: Int = StoreManager.freeRotationMaxWeeks
    @State private var dayStartHour: Int = 7
    @State private var nightStartHour: Int = 19
    @State private var replaceExisting: Bool = true

    private var activeJob: JobProfile? {
        if let id = selectedJobId, let j = shiftStore.job(for: id) { return j }
        return shiftStore.jobs.first
    }

    private var requiresProForSelectedWeeks: Bool {
        !store.canPaintRotation(weeks: weeks)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Choose Shift Rotation Pattern", "选择经典倒班模板", "選擇經典輪班模板")) {
                    ForEach(RotationPattern.allCases) { pat in
                        let active = selectedPattern == pat
                        Button {
                            selectedPattern = pat
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(active ? ShiftTheme.cobalt : ShiftTheme.border)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pat.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(ShiftTheme.ink)
                                    Text(pat.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(ShiftTheme.muted)
                                    HStack(spacing: 3) {
                                        ForEach(0..<min(14, pat.cycle.count), id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(pat.cycle[i].color)
                                                .frame(width: 14, height: 6)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(L10n.t("Schedule Parameters", "排班生成参数", "更表產生參數")) {
                    Picker(L10n.t("Target Job", "适用工作", "套用工作"), selection: Binding(
                        get: { selectedJobId ?? shiftStore.jobs.first?.id ?? UUID() },
                        set: { selectedJobId = $0 }
                    )) {
                        ForEach(shiftStore.jobs) { job in
                            Text(job.name).tag(job.id)
                        }
                    }

                    DatePicker(L10n.t("Start Date", "起始日期", "起始日期"), selection: $startDate, displayedComponents: [.date])

                    Stepper(value: $weeks, in: 1...52) {
                        HStack {
                            Text(L10n.t("Duration", "排班周数", "排班週數"))
                            Spacer()
                            HStack(spacing: 5) {
                                Text(L10n.t("\(weeks)w (\(weeks * 7)d)", "\(weeks) 周（\(weeks * 7) 天）", "\(weeks) 週（\(weeks * 7) 天）"))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(requiresProForSelectedWeeks ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt)
                                if requiresProForSelectedWeeks {
                                    Text("PRO")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(ShiftTheme.overtimeAmber)
                                        .foregroundStyle(ShiftTheme.midnightIndigo)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Quick duration chips (2w Free taste vs Full-Year Pro)
                    HStack(spacing: 8) {
                        ForEach([2, 4, 12, 52], id: \.self) { preset in
                            let selected = weeks == preset
                            let isLocked = !store.canPaintRotation(weeks: preset)
                            Button {
                                weeks = preset
                            } label: {
                                HStack(spacing: 3) {
                                    Text(preset == 52 ? L10n.t("1 Year", "全年", "全年") : "\(preset)w")
                                    if isLocked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 8.5))
                                    }
                                }
                                .font(.caption2.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(selected ? (isLocked ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt) : ShiftTheme.cardElevated)
                                .foregroundStyle(selected ? (isLocked ? ShiftTheme.midnightIndigo : .white) : ShiftTheme.ink)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !store.isPro {
                        Text(
                            L10n.t(
                                "Free plan paints up to 2 weeks at once to try it out. Unlock Pro to auto-paint up to a full year (52 weeks) in 1 tap.",
                                "免费版支持单次填充 2 周体验；解锁 FlatShift Pro 可一键铺满全年（52 周）排班。",
                                "免費版支援單次自動填入 2 週體驗；解鎖 FlatShift Pro 可一鍵鋪滿全年（52 週）排班更表。"
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                    }

                    Stepper(value: $dayStartHour, in: 5...12) {
                        HStack {
                            Text(L10n.t("Day Shift Start", "白班上班点", "早班開始時間"))
                            Spacer()
                            Text(String(format: "%02d:00", dayStartHour))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(ShiftTheme.muted)
                        }
                    }

                    Stepper(value: $nightStartHour, in: 17...23) {
                        HStack {
                            Text(L10n.t("Night Shift Start", "夜班上班点", "夜班開始時間"))
                            Spacer()
                            Text(String(format: "%02d:00", nightStartHour))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(ShiftTheme.muted)
                        }
                    }

                    Toggle(L10n.t("Replace existing shifts in date range", "覆盖该日期段已有同工作排班", "覆蓋此日期範圍內既有更表"), isOn: $replaceExisting)
                }

                Section {
                    Button {
                        if requiresProForSelectedWeeks {
                            let msg = L10n.t(
                                "Free plan paints up to 2 weeks at a time. Unlock FlatShift Pro to auto-paint \(weeks) weeks (up to a full year) in 1 tap.",
                                "免费版单次最多自动排班 2 周。升级 FlatShift Pro 即可一键填入 \(weeks) 周乃至全年（52 周）倒班表。",
                                "免費版單次最多自動填入 2 週更表。升級 FlatShift Pro 即可一鍵鋪滿 \(weeks) 週甚至全年（52 週）輪班表。"
                            )
                            dismiss()
                            onRequestPaywall?(msg)
                            return
                        }
                        guard let job = activeJob else { return }
                        let count = shiftStore.applyRotation(
                            pattern: selectedPattern,
                            job: job,
                            startDate: startDate,
                            weeks: weeks,
                            dayStartHour: dayStartHour,
                            nightStartHour: nightStartHour,
                            replaceExistingForJobInRange: replaceExisting
                        )
                        onApplied?(count)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                requiresProForSelectedWeeks
                                    ? L10n.t("Unlock Full-Year Rotation Painter (Pro)", "解锁全年自动倒班排班 (Pro)", "解鎖全年自動排班更表 (Pro)")
                                    : L10n.t("Paint Rotation onto Calendar", "一键批量填入倒班日历", "一鍵批量填入排班更表"),
                                systemImage: requiresProForSelectedWeeks ? "lock.open.fill" : "wand.and.stars"
                            )
                            .font(.headline.weight(.bold))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .tint(requiresProForSelectedWeeks ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt)
                }
            }
            .navigationTitle(L10n.t("Rotation Painter", "一键倒班排班", "一鍵輪班更表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消", "取消")) { dismiss() }
                }
            }
            .onAppear {
                if selectedJobId == nil {
                    selectedJobId = shiftStore.jobs.first?.id
                }
                if store.isPro && weeks == StoreManager.freeRotationMaxWeeks {
                    weeks = 4
                }
            }
        }
    }
}
