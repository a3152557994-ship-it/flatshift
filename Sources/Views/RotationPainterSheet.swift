import SwiftUI

struct RotationPainterSheet: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @Environment(\.dismiss) private var dismiss

    var onApplied: ((Int) -> Void)? = nil

    @State private var selectedPattern: RotationPattern = .nurse3x12
    @State private var selectedJobId: UUID? = nil
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var weeks: Int = 4
    @State private var dayStartHour: Int = 7
    @State private var nightStartHour: Int = 19
    @State private var replaceExisting: Bool = true

    private var activeJob: JobProfile? {
        if let id = selectedJobId, let j = shiftStore.job(for: id) { return j }
        return shiftStore.jobs.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Choose Shift Rotation Pattern", "选择经典倒班模板")) {
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
                                    // Pattern color swatch preview (first 14 days)
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

                Section(L10n.t("Schedule Parameters", "排班生成参数")) {
                    Picker(L10n.t("Target Job", "适用工作"), selection: Binding(
                        get: { selectedJobId ?? shiftStore.jobs.first?.id ?? UUID() },
                        set: { selectedJobId = $0 }
                    )) {
                        ForEach(shiftStore.jobs) { job in
                            Text(job.name).tag(job.id)
                        }
                    }

                    DatePicker(L10n.t("Start Date", "起始日期"), selection: $startDate, displayedComponents: [.date])

                    Stepper(value: $weeks, in: 1...12) {
                        HStack {
                            Text(L10n.t("Duration", "排班周数"))
                            Spacer()
                            Text(L10n.t("\(weeks) weeks (\(weeks * 7) days)", "\(weeks) 周（共 \(weeks * 7) 天）"))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(ShiftTheme.cobalt)
                        }
                    }

                    Stepper(value: $dayStartHour, in: 5...12) {
                        HStack {
                            Text(L10n.t("Day Shift Start", "白班上班点"))
                            Spacer()
                            Text(String(format: "%02d:00", dayStartHour))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(ShiftTheme.muted)
                        }
                    }

                    Stepper(value: $nightStartHour, in: 17...23) {
                        HStack {
                            Text(L10n.t("Night Shift Start", "夜班上班点"))
                            Spacer()
                            Text(String(format: "%02d:00", nightStartHour))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(ShiftTheme.muted)
                        }
                    }

                    Toggle(L10n.t("Replace existing shifts in date range", "覆盖该日期段已有同工作排班"), isOn: $replaceExisting)
                }

                Section {
                    Button {
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
                            Label(L10n.t("Paint Rotation onto Calendar", "一键批量填入倒班日历"), systemImage: "wand.and.stars")
                                .font(.headline.weight(.bold))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .tint(ShiftTheme.cobalt)
                }
            }
            .navigationTitle(L10n.t("Rotation Painter", "一键倒班排班"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { dismiss() }
                }
            }
            .onAppear {
                if selectedJobId == nil {
                    selectedJobId = shiftStore.jobs.first?.id
                }
            }
        }
    }
}
