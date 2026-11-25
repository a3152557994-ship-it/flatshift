import SwiftUI

struct ClockHomeView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager

    var onOpenPaywall: (String?) -> Void

    @State private var periodOffset: Int = 0
    @State private var selectedJobFilterId: UUID? = nil
    @State private var clockJobId: UUID? = nil
    @State private var clockShiftType: ShiftType = .night
    @State private var editingShift: ShiftEntry? = nil
    @State private var isNewShift: Bool = false
    @State private var toastMessage: String? = nil

    private var periodRange: (start: Date, end: Date) {
        PayEngine.payPeriodRange(cycle: shiftStore.preferences.payPeriodCycle, offset: periodOffset)
    }

    private var summary: PayPeriodSummary {
        PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: periodRange.start,
            periodEnd: periodRange.end,
            filterJobId: selectedJobFilterId,
            defaultCurrency: shiftStore.preferences.currencySymbol
        )
    }

    private var activeClockJob: JobProfile? {
        if let sid = shiftStore.activeSession?.jobId {
            return shiftStore.job(for: sid)
        }
        if let cid = clockJobId, let j = shiftStore.job(for: cid) {
            return j
        }
        return shiftStore.jobs.first
    }

    private var periodLabel: String {
        let df = DateFormatter()
        df.locale = L10n.locale
        df.dateFormat = L10n.t("MMM d", "M月d日")
        return "\(df.string(from: periodRange.start)) – \(df.string(from: periodRange.end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Live Pay Period Hero Card
                    payPeriodHeroCard

                    // MARK: - 1-Tap Live Clock-In / Break / Clock-Out Card
                    liveClockCard

                    // MARK: - Job Filter Chips
                    if shiftStore.jobs.count > 1 {
                        jobFilterStrip
                    }

                    if let toastMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ShiftTheme.shiftMint)
                            Text(toastMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShiftTheme.ink)
                            Spacer()
                        }
                        .padding(12)
                        .background(ShiftTheme.shiftMint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // MARK: - Recent Shifts in Period
                    recentShiftsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(ShiftTheme.canvas.ignoresSafeArea())
            .navigationTitle(L10n.t("FlatShift", "FlatShift 倒班算薪"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            toggleNightMode()
                        } label: {
                            Image(systemName: shiftStore.preferences.appearanceMode == .nightDark ? "sun.max.fill" : "moon.stars.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(shiftStore.preferences.appearanceMode == .nightDark ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt)
                                .padding(7)
                                .background(ShiftTheme.card)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(ShiftTheme.border, lineWidth: 1))
                        }
                        .accessibilityLabel(L10n.t("Toggle Night Shift Dark Mode", "切换夜班深色模式"))

                        if store.isPro {
                            Text("PRO")
                                .font(.caption2.weight(.black))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(ShiftTheme.shiftMint)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        } else {
                            Button {
                                onOpenPaywall(nil)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "seal.fill")
                                        .font(.caption2)
                                    Text(L10n.t("Lifetime \(store.displayPrice(for: FlatShiftProductID.lifetime))", "买断 \(store.displayPrice(for: FlatShiftProductID.lifetime))"))
                                        .font(.caption.weight(.bold).monospacedDigit())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ShiftTheme.overtimeAmber)
                                .foregroundStyle(ShiftTheme.midnightIndigo)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .sheet(item: $editingShift) { target in
                ShiftEditorSheet(shift: target, isNew: isNewShift) { _ in
                    showToast(L10n.t("Shift saved & pay recalculated.", "班次已保存，薪资已重算。"))
                }
            }
            .onAppear {
                if clockJobId == nil {
                    clockJobId = shiftStore.jobs.first?.id
                }
            }
        }
    }

    // MARK: - Hero Card
    private var payPeriodHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shiftStore.preferences.payPeriodCycle.title.uppercased() + " · " + L10n.t("PAY PERIOD", "计薪周期"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.white.opacity(0.65))
                    Text(periodLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button { periodOffset -= 1 } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    if periodOffset != 0 {
                        Button(L10n.t("Now", "本期")) { periodOffset = 0 }
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Button { periodOffset += 1 } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("EST. NET TAKE-HOME", "预估税后到手"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ShiftTheme.shiftMint)
                    Text(PayEngine.formatMoney(summary.estimatedNetPay, symbol: summary.currencySymbol))
                        .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(L10n.t("GROSS PAY", "税前应发"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.65))
                    Text(PayEngine.formatMoney(summary.totalGrossPay, symbol: summary.currencySymbol))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.92))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
            }

            // 3 Metric Pills: Regular, OT, Differentials
            HStack(spacing: 8) {
                heroPill(
                    label: L10n.t("Regular", "正常工时"),
                    value: PayEngine.formatHours(summary.totalRegularHours),
                    color: .white
                )
                heroPill(
                    label: L10n.t("Overtime", "加班工时"),
                    value: PayEngine.formatHours(summary.totalOTCombinedHours),
                    color: ShiftTheme.overtimeAmber
                )
                heroPill(
                    label: L10n.t("Diff Bonus", "夜/周津贴"),
                    value: "+" + PayEngine.formatMoney(summary.totalDifferentialPay, symbol: summary.currencySymbol),
                    color: Color(red: 167/255, green: 139/255, blue: 250/255)
                )
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [ShiftTheme.midnightIndigo, Color(red: 25/255, green: 37/255, blue: 66/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ShiftTheme.cobalt.opacity(0.35), lineWidth: 1)
        )
    }

    private func heroPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: - Live Clock-In / Out Card
    private var liveClockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let session = shiftStore.activeSession {
                let job = shiftStore.job(for: session.jobId) ?? shiftStore.jobs.first
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let secs = session.elapsedWorkSeconds(at: context.date)
                    let hrs = Int(secs) / 3600
                    let mins = (Int(secs) % 3600) / 60
                    let remSecs = Int(secs) % 60
                    let estPay = (secs / 3600.0) * ((job?.hourlyRate ?? 0) + (session.applyNightDiff ? (job?.nightDifferentialPerHour ?? 0) : 0))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(session.isOnBreak ? ShiftTheme.overtimeAmber : ShiftTheme.shiftMint)
                                    .frame(width: 9, height: 9)
                                Text(session.isOnBreak ? L10n.t("ON UNPAID BREAK", "休息计时中") : L10n.t("ON THE CLOCK · LIVE", "正在上班 · 实时计时"))
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(session.isOnBreak ? ShiftTheme.overtimeAmber : ShiftTheme.shiftMint)
                            }
                            Spacer()
                            Text(job?.name ?? "")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShiftTheme.muted)
                                .lineLimit(1)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%02d:%02d:%02d", hrs, mins, remSecs))
                                .font(.system(size: 38, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(ShiftTheme.ink)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(L10n.t("Earned So Far", "已计薪资"))
                                    .font(.caption2)
                                    .foregroundStyle(ShiftTheme.muted)
                                Text(PayEngine.formatMoney(estPay, symbol: job?.currencySymbol ?? "$"))
                                    .font(.headline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(ShiftTheme.shiftMint)
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                shiftStore.toggleQuick30MinBreak()
                            } label: {
                                Label(
                                    session.quickBreakMinutes > 0
                                        ? L10n.t("-30m Break ON", "已扣30m休")
                                        : L10n.t("+30m Break", "扣30m休息"),
                                    systemImage: "cup.and.saucer.fill"
                                )
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(session.quickBreakMinutes > 0 ? ShiftTheme.overtimeAmber.opacity(0.2) : ShiftTheme.cardElevated)
                                .foregroundStyle(session.quickBreakMinutes > 0 ? ShiftTheme.overtimeAmber : ShiftTheme.ink)
                                .clipShape(Capsule())
                            }

                            Button {
                                shiftStore.toggleBreak()
                            } label: {
                                Label(
                                    session.isOnBreak ? L10n.t("Resume", "结束休息") : L10n.t("Pause", "暂停休息"),
                                    systemImage: session.isOnBreak ? "play.fill" : "pause.fill"
                                )
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(ShiftTheme.cardElevated)
                                .foregroundStyle(ShiftTheme.ink)
                                .clipShape(Capsule())
                            }

                            Button {
                                shiftStore.toggleActiveNightDiff()
                            } label: {
                                Label(L10n.t("Night Diff", "夜班津贴"), systemImage: "moon.fill")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(session.applyNightDiff ? ShiftTheme.nightViolet.opacity(0.2) : ShiftTheme.cardElevated)
                                    .foregroundStyle(session.applyNightDiff ? ShiftTheme.nightViolet : ShiftTheme.muted)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                if let saved = shiftStore.clockOutAndSave() {
                                    showToast(L10n.t("Clocked out · Saved \(PayEngine.formatHours(saved.payableHours)) shift!", "已下班打卡 · 记录 \(PayEngine.formatHours(saved.payableHours)) 班次！"))
                                }
                            } label: {
                                Label(L10n.t("Clock Out & Save Shift", "下班打卡并算薪"), systemImage: "stop.circle.fill")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(ShiftTheme.ptoRose)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            Button {
                                shiftStore.cancelActiveSession()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.subheadline.weight(.bold))
                                    .padding(13)
                                    .background(ShiftTheme.cardElevated)
                                    .foregroundStyle(ShiftTheme.muted)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
            } else {
                // Idle 1-Tap Clock-In Deck
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("1-Tap Live Shift Clock", "一键实时上下班打卡"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(ShiftTheme.ink)
                        if let job = activeClockJob {
                            Text("\(job.name) · \(PayEngine.formatMoney(job.hourlyRate, symbol: job.currencySymbol))/hr")
                                .font(.caption)
                                .foregroundStyle(ShiftTheme.muted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if shiftStore.jobs.count > 1 {
                        Menu {
                            ForEach(shiftStore.jobs) { job in
                                Button(job.name) { clockJobId = job.id }
                            }
                        } label: {
                            Label(L10n.t("Switch", "切换工作"), systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ShiftTheme.cobaltSoft)
                                .foregroundStyle(ShiftTheme.cobalt)
                                .clipShape(Capsule())
                        }
                    }
                }

                // Shift type quick selector
                HStack(spacing: 8) {
                    ForEach([ShiftType.day, .night, .swing, .overtime], id: \.self) { st in
                        let active = clockShiftType == st
                        Button {
                            clockShiftType = st
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: st.iconName).font(.caption2)
                                Text(st.shortBadge).font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(active ? st.color : ShiftTheme.cardElevated)
                            .foregroundStyle(active ? .white : ShiftTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        if let job = activeClockJob {
                            shiftStore.clockIn(jobId: job.id, shiftType: clockShiftType)
                        }
                    } label: {
                        Label(L10n.t("Clock In Now", "立即上班打卡"), systemImage: "play.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        openNewManualShift()
                    } label: {
                        Label(L10n.t("Manual", "补录"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(ShiftTheme.cardElevated)
                            .foregroundStyle(ShiftTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ShiftTheme.border, lineWidth: 1))
                    }
                }
            }
        }
        .shiftCard(padding: 16, cornerRadius: 18)
    }

    // MARK: - Job Filter Chips
    private var jobFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: L10n.t("All Jobs", "全部工作"), active: selectedJobFilterId == nil) {
                    selectedJobFilterId = nil
                }
                ForEach(shiftStore.jobs) { job in
                    filterChip(title: job.name, active: selectedJobFilterId == job.id) {
                        selectedJobFilterId = job.id
                    }
                }
            }
        }
    }

    private func filterChip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(active ? ShiftTheme.cobalt : ShiftTheme.card)
                .foregroundStyle(active ? .white : ShiftTheme.ink)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? ShiftTheme.cobalt : ShiftTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Shifts
    private var recentShiftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("Shifts This Period (\(summary.totalShiftsWorked))", "本期出勤班次（\(summary.totalShiftsWorked) 班）"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ShiftTheme.ink)
                Spacer()
                Button {
                    openNewManualShift()
                } label: {
                    Label(L10n.t("Add Shift", "记一班"), systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ShiftTheme.cobalt)
                }
            }

            let payable = summary.breakdowns.filter { $0.shift.shiftType.isPayable }.reversed()
            if payable.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(ShiftTheme.muted)
                    Text(L10n.t("No shifts logged in this pay period yet.", "本期暂未记录出勤班次。"))
                        .font(.subheadline)
                        .foregroundStyle(ShiftTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .shiftCard()
            } else {
                ForEach(Array(payable)) { item in
                    Button {
                        isNewShift = false
                        editingShift = item.shift
                    } label: {
                        ShiftRowCard(breakdown: item, use24Hour: shiftStore.preferences.use24HourTime)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openNewManualShift() {
        let job = activeClockJob ?? shiftStore.jobs.first
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .hour, value: 7, to: today) ?? Date()
        let breakMins = job?.defaultUnpaidBreakMinutes ?? 30
        let end = cal.date(byAdding: .minute, value: 12 * 60 + breakMins, to: start) ?? start.addingTimeInterval(12.5 * 3600)
        isNewShift = true
        editingShift = ShiftEntry(
            jobId: job?.id ?? UUID(),
            shiftType: .day,
            startDate: start,
            endDate: end,
            unpaidBreakMinutes: breakMins,
            applyNightDiff: false,
            applyWeekendDiff: PayEngine.isWeekend(start)
        )
    }

    private func toggleNightMode() {
        shiftStore.preferences.appearanceMode = (shiftStore.preferences.appearanceMode == .nightDark) ? .light : .nightDark
        shiftStore.save()
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            if toastMessage == msg { toastMessage = nil }
        }
    }
}

struct ShiftRowCard: View {
    let breakdown: ShiftPayBreakdown
    let use24Hour: Bool

    private var dateLabel: String {
        let df = DateFormatter()
        df.locale = L10n.locale
        df.dateFormat = L10n.t("EEE, MMM d", "M月d日 EEE")
        return df.string(from: breakdown.shift.startDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color pill badge
            VStack(spacing: 3) {
                Image(systemName: breakdown.shift.shiftType.iconName)
                    .font(.caption.weight(.bold))
                Text(breakdown.shift.shiftType.shortBadge)
                    .font(.system(size: 9, weight: .heavy))
            }
            .frame(width: 48, height: 48)
            .background(breakdown.shift.shiftType.color.opacity(0.16))
            .foregroundStyle(breakdown.shift.shiftType.color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(dateLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ShiftTheme.ink)
                    if breakdown.totalOTHours > 0 {
                        Text(L10n.t("OT \(PayEngine.formatHours(breakdown.totalOTHours))", "加班 \(PayEngine.formatHours(breakdown.totalOTHours))"))
                            .font(.system(size: 10, weight: .heavy).monospacedDigit())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ShiftTheme.overtimeAmber.opacity(0.18))
                            .foregroundStyle(ShiftTheme.overtimeAmber)
                            .clipShape(Capsule())
                    }
                    if breakdown.differentialPay > 0 {
                        Text(L10n.t("DIFF", "津贴"))
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ShiftTheme.nightViolet.opacity(0.18))
                            .foregroundStyle(ShiftTheme.nightViolet)
                            .clipShape(Capsule())
                    }
                }

                Text(breakdown.job.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ShiftTheme.muted)
                    .lineLimit(1)

                Text("\(PayEngine.formatTime(breakdown.shift.startDate, use24Hour: use24Hour)) – \(PayEngine.formatTime(breakdown.shift.endDate, use24Hour: use24Hour))  ·  \(PayEngine.formatHours(breakdown.totalHours))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(ShiftTheme.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(PayEngine.formatMoney(breakdown.grossPay, symbol: breakdown.job.currencySymbol))
                    .font(.subheadline.weight(.heavy).monospacedDigit())
                    .foregroundStyle(ShiftTheme.ink)
                Text(L10n.t("Net \(PayEngine.formatMoney(breakdown.estimatedNetPay, symbol: breakdown.job.currencySymbol))", "到手 \(PayEngine.formatMoney(breakdown.estimatedNetPay, symbol: breakdown.job.currencySymbol))"))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(ShiftTheme.shiftMint)
            }
        }
        .shiftCard(padding: 12, cornerRadius: 14)
    }
}
