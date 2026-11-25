import SwiftUI
import UIKit

struct CalendarTabView: View {
    @EnvironmentObject private var shiftStore: ShiftStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var reviewManager: ReviewPromptManager

    var onOpenPaywall: (String?) -> Void

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showRotationSheet: Bool = false
    @State private var editingShift: ShiftEntry? = nil
    @State private var isNewShift: Bool = false
    @State private var bannerNote: String? = nil

    // 1-Tap Viral Share Schedule Image
    @State private var shareImageItem: UIImage? = nil
    @State private var showScheduleShareSheet: Bool = false
    @State private var proIncludeBadge: Bool = false

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // Monday first
        return c
    }

    private var monthBounds: (start: Date, end: Date) {
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        let start = cal.date(from: comps) ?? displayedMonth
        let next = cal.date(byAdding: .month, value: 1, to: start) ?? start
        let end = cal.date(byAdding: .second, value: -1, to: next) ?? start
        return (start, end)
    }

    private var monthSummary: PayPeriodSummary {
        PayEngine.summarize(
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            periodStart: monthBounds.start,
            periodEnd: monthBounds.end,
            defaultCurrency: shiftStore.preferences.currencySymbol
        )
    }

    private var breakdownsByDay: [Date: [ShiftPayBreakdown]] {
        Dictionary(grouping: monthSummary.breakdowns) { b in
            cal.startOfDay(for: b.shift.startDate)
        }
    }

    private var selectedDayBreakdowns: [ShiftPayBreakdown] {
        breakdownsByDay[cal.startOfDay(for: selectedDate)] ?? []
    }

    private var monthTitle: String {
        let df = DateFormatter()
        df.locale = L10n.locale
        df.dateFormat = L10n.t("MMMM yyyy", "yyyy年M月", "yyyy年M月")
        return df.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        L10n.isChinese
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }

    private var calendarCells: [Date?] {
        let start = monthBounds.start
        let range = cal.range(of: .day, in: .month, for: start) ?? 1..<31
        let firstWeekday = cal.component(.weekday, from: start) // 1=Sun, 2=Mon...7=Sat
        let leadingBlanks = (firstWeekday - cal.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                cells.append(d)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // MARK: - Month Header
                    monthControlHeader

                    // MARK: - Monthly KPI Ribbon
                    monthlyKPIRibbon

                    if let bannerNote {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(ShiftTheme.shiftMint)
                            Text(bannerNote)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShiftTheme.ink)
                            Spacer()
                        }
                        .padding(11)
                        .background(ShiftTheme.shiftMint.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // MARK: - Color-Coded Monthly Shift Calendar Grid
                    calendarGridCard

                    // MARK: - Legend Strip
                    legendStrip

                    // MARK: - 1-Tap Viral Share Schedule Image CTA
                    shareScheduleImageCard

                    // MARK: - Selected Day Detail Drawer
                    selectedDayDrawer
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(ShiftTheme.canvas.ignoresSafeArea())
            .navigationTitle(L10n.t("Shift Calendar", "倒班日历", "排班更表"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        shiftStore.preferences.appearanceMode = (shiftStore.preferences.appearanceMode == .nightDark) ? .light : .nightDark
                        shiftStore.save()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: shiftStore.preferences.appearanceMode == .nightDark ? "sun.max.fill" : "moon.stars.fill")
                            Text(
                                shiftStore.preferences.appearanceMode == .nightDark
                                    ? L10n.t("Day", "日间", "日間")
                                    : L10n.t("Night", "夜班深色", "夜班深色")
                            )
                            .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(shiftStore.preferences.appearanceMode == .nightDark ? ShiftTheme.overtimeAmber.opacity(0.18) : ShiftTheme.cobaltSoft)
                        .foregroundStyle(shiftStore.preferences.appearanceMode == .nightDark ? ShiftTheme.overtimeAmber : ShiftTheme.cobalt)
                        .clipShape(Capsule())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRotationSheet = true
                    } label: {
                        Label(L10n.t("Rotations", "一键倒班", "一鍵排更"), systemImage: "wand.and.stars")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ShiftTheme.cobalt)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showRotationSheet) {
                RotationPainterSheet(
                    onApplied: { count in
                        FunnelMetrics.shared.record(.rotationPainted)
                        bannerNote = L10n.t(
                            "Painted \(count) rotation entries onto your calendar!",
                            "已一键填入 \(count) 天倒班排班记录！",
                            "已一鍵填入 \(count) 天輪班更表記錄！"
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { bannerNote = nil }
                    },
                    onRequestPaywall: { msg in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onOpenPaywall(msg)
                        }
                    }
                )
            }
            .sheet(item: $editingShift) { target in
                ShiftEditorSheet(shift: target, isNew: isNewShift) { _ in
                    if isNewShift {
                        reviewManager.recordShiftLogged()
                    }
                }
            }
            .sheet(isPresented: $showScheduleShareSheet, onDismiss: {
                reviewManager.recordScheduleImageShared()
            }) {
                if let img = shareImageItem {
                    ActivityShareSheet(items: [img])
                }
            }
            .onAppear {
                let todayKey = cal.startOfDay(for: Date())
                if breakdownsByDay[todayKey] == nil,
                   let firstWithShift = monthSummary.breakdowns.first(where: { $0.shift.shiftType.isPayable }) {
                    selectedDate = cal.startOfDay(for: firstWithShift.shift.startDate)
                }
            }
        }
    }

    private var monthControlHeader: some View {
        HStack {
            Button {
                if let prev = cal.date(byAdding: .month, value: -1, to: displayedMonth) {
                    displayedMonth = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .background(ShiftTheme.card)
                    .foregroundStyle(ShiftTheme.ink)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ShiftTheme.border, lineWidth: 1))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(ShiftTheme.ink)
                Text(L10n.t("Tap any day to inspect or edit shifts", "点击任意日期查看明细或补录班次", "點擊任意日期檢視明細或補錄更次"))
                    .font(.caption2)
                    .foregroundStyle(ShiftTheme.muted)
            }

            Spacer()

            Button {
                if let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) {
                    displayedMonth = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 34, height: 34)
                    .background(ShiftTheme.card)
                    .foregroundStyle(ShiftTheme.ink)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ShiftTheme.border, lineWidth: 1))
            }
        }
    }

    private var monthlyKPIRibbon: some View {
        HStack(spacing: 8) {
            kpiCell(
                label: L10n.t("SHIFTS", "出勤班次", "當月更數"),
                value: "\(monthSummary.totalShiftsWorked)",
                color: ShiftTheme.ink
            )
            kpiCell(
                label: L10n.t("HOURS (OT)", "总工时(加班)", "總工時(加班)"),
                value: "\(PayEngine.formatHours(monthSummary.totalHours)) (\(PayEngine.formatHours(monthSummary.totalOTCombinedHours)))",
                color: ShiftTheme.overtimeAmber
            )
            kpiCell(
                label: L10n.t("EST. GROSS", "本月预估应发", "本月預估總薪"),
                value: PayEngine.formatMoney(monthSummary.totalGrossPay, symbol: monthSummary.currencySymbol),
                color: ShiftTheme.shiftMint
            )
        }
    }

    private func kpiCell(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ShiftTheme.muted)
            Text(value)
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shiftCard(padding: 10, cornerRadius: 12)
    }

    private var calendarGridCard: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let todayStart = cal.startOfDay(for: Date())
        let selectedStart = cal.startOfDay(for: selectedDate)

        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ShiftTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                }

                ForEach(Array(calendarCells.enumerated()), id: \.offset) { _, dateOpt in
                    if let date = dateOpt {
                        let dayStart = cal.startOfDay(for: date)
                        let dayItems = breakdownsByDay[dayStart] ?? []
                        let isSelected = dayStart == selectedStart
                        let isToday = dayStart == todayStart
                        let primaryShift = dayItems.first(where: { $0.shift.shiftType.isPayable }) ?? dayItems.first
                        let dayGross = dayItems.reduce(0) { $0 + $1.grossPay }

                        Button {
                            selectedDate = dayStart
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(cal.component(.day, from: date))")
                                    .font(.system(size: 12, weight: isToday || isSelected ? .heavy : .semibold).monospacedDigit())
                                    .foregroundStyle(isSelected ? .white : (isToday ? ShiftTheme.cobalt : ShiftTheme.ink))

                                if let primary = primaryShift {
                                    Text(primary.shift.shiftType.shortBadge)
                                        .font(.system(size: 8.5, weight: .black))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .frame(maxWidth: .infinity)
                                        .background(isSelected ? Color.white.opacity(0.24) : primary.shift.shiftType.color)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                } else {
                                    Spacer().frame(height: 15)
                                }

                                if dayGross > 0 {
                                    Text("\(monthSummary.currencySymbol)\(Int(dayGross.rounded()))")
                                        .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : ShiftTheme.shiftMint)
                                } else {
                                    Spacer().frame(height: 11)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 3)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(
                                isSelected
                                    ? ShiftTheme.cobalt
                                    : (isToday ? ShiftTheme.cobaltSoft : ShiftTheme.cardElevated)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isToday && !isSelected ? ShiftTheme.cobalt : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 58)
                    }
                }
            }
        }
        .shiftCard(padding: 10, cornerRadius: 16)
    }

    private var legendStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ShiftType.allCases) { st in
                    HStack(spacing: 4) {
                        Circle().fill(st.color).frame(width: 8, height: 8)
                        Text(st.shortBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ShiftTheme.muted)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 1-Tap Viral "Share Schedule Image" Card
    private var shareScheduleImageCard: some View {
        VStack(spacing: 8) {
            Button {
                shareSchedulePNG()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("Share Schedule Image", "一键生成并分享月度排班图", "一鍵分享本月排班更表圖"))
                            .font(.subheadline.weight(.heavy))
                        Text(L10n.t("Clean PNG grid for family & coworkers (no dollar amounts shown)", "高清排班卡片发给家人与同事（自动隐藏薪资金额）", "高清更表卡片傳給家人與同事（自動隱藏薪資金額）"))
                            .font(.caption2)
                            .opacity(0.86)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(ShiftTheme.midnightIndigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if store.isPro {
                Toggle(isOn: $proIncludeBadge) {
                    Text(L10n.t("Show subtle FlatShift badge on shared image", "分享图片底部保留 FlatShift 小标签", "分享圖片底部保留 FlatShift 小標示"))
                        .font(.caption2)
                        .foregroundStyle(ShiftTheme.muted)
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private func shareSchedulePNG() {
        let includeBadge = store.isPro ? proIncludeBadge : true
        let image = ScheduleImageRenderer.renderMonthlyScheduleImage(
            monthDate: displayedMonth,
            shifts: shiftStore.shifts,
            jobs: shiftStore.jobs,
            employeeName: shiftStore.preferences.employeeName,
            use24HourTime: shiftStore.preferences.use24HourTime,
            includeBrandingBadge: includeBadge,
            darkTheme: shiftStore.preferences.appearanceMode == .nightDark,
            calendar: cal
        )
        shareImageItem = image
        showScheduleShareSheet = true
    }

    private var selectedDayDrawer: some View {
        let df = DateFormatter()
        df.locale = L10n.locale
        df.dateFormat = L10n.t("EEEE, MMM d", "M月d日 EEEE", "M月d日 EEEE")

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(df.string(from: selectedDate))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(ShiftTheme.ink)
                Spacer()
                Button {
                    addShiftOnSelectedDay()
                } label: {
                    Label(L10n.t("Add Shift", "添加班次", "新增更次"), systemImage: "plus.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ShiftTheme.cobalt)
                }
            }

            if selectedDayBreakdowns.isEmpty {
                HStack {
                    Text(L10n.t("No shift scheduled on this date.", "当天暂无排班，可点击右上角添加。", "當日暫無排班，可點右上角新增。"))
                        .font(.caption)
                        .foregroundStyle(ShiftTheme.muted)
                    Spacer()
                }
                .padding(.vertical, 6)
            } else {
                ForEach(selectedDayBreakdowns) { item in
                    Button {
                        isNewShift = false
                        editingShift = item.shift
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.shift.shiftType.color)
                                .frame(width: 5, height: 42)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(item.shift.shiftType.fullName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(ShiftTheme.ink)
                                    if item.shift.shiftType.isPayable {
                                        Text("\(PayEngine.formatTime(item.shift.startDate, use24Hour: shiftStore.preferences.use24HourTime))–\(PayEngine.formatTime(item.shift.endDate, use24Hour: shiftStore.preferences.use24HourTime))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(ShiftTheme.muted)
                                    }
                                }
                                Text(item.job.name + (item.shift.notes.isEmpty ? "" : " · \(item.shift.notes)"))
                                    .font(.caption)
                                    .foregroundStyle(ShiftTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if item.grossPay > 0 {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(PayEngine.formatMoney(item.grossPay, symbol: item.job.currencySymbol))
                                        .font(.subheadline.weight(.heavy).monospacedDigit())
                                        .foregroundStyle(ShiftTheme.ink)
                                    Text(PayEngine.formatHours(item.totalHours))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(ShiftTheme.shiftMint)
                                }
                            } else {
                                Text(item.shift.shiftType.shortBadge)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ShiftTheme.muted)
                            }
                        }
                        .padding(10)
                        .background(ShiftTheme.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .shiftCard(padding: 14, cornerRadius: 16)
    }

    private func addShiftOnSelectedDay() {
        let job = shiftStore.jobs.first
        let start = cal.date(byAdding: .hour, value: 7, to: cal.startOfDay(for: selectedDate)) ?? selectedDate
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
}
