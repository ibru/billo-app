//  Created by Jiri Urbasek on 12/19/25.

import SwiftUI

struct CalendarTodayDividerRow: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)
            Text("Today")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.yellow)
                .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DesignSystem.Color.yellow.opacity(0.15))
                )

            line
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background(Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }

    private var line: some View {
        Rectangle()
            .fill(DesignSystem.Color.yellow.opacity(0.35))
            .frame(height: 1)
    }
}

struct CalendarTodayDividerRow2: View {
    let date: Date

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(DesignSystem.Color.yellow.opacity(0.25))
                .frame(height: 1)

            HStack(spacing: DesignSystem.Spacing.small) {
                CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.yellow)
                    .padding(.horizontal, DesignSystem.Spacing.mediumSmall)
                    .padding(.vertical, DesignSystem.Spacing.extraSmall)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Color.background)
                            .overlay(
                                Capsule()
                                    .stroke(DesignSystem.Color.yellow.opacity(0.6), lineWidth: 1)
                            )
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerRow3: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    // MARK: - Pick one icon for Today divider
//                    Image(systemName: "location.fill")
//                    Image(systemName: "mappin")
//                    Image(systemName: "scope")
//                    Image(systemName: "clock.fill")
                    Image(systemName: "sun.max")
//                    Image(systemName: "sun.min")
//                    Image(systemName: "arrowtriangle.right.fill")
//                    Image(systemName: "chevron.right")
//                    Image(systemName: "smallcircle.filled.circle")
//                    Image(systemName: "diamond.fill")
//                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Color.yellow)
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.Color.yellow)
                }

                Rectangle()
                    .fill(DesignSystem.Color.yellow.opacity(0.25))
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerRow4: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)

            Text("Today")
                .font(.footnote.weight(.bold))
                .foregroundStyle(DesignSystem.Color.yellow)
                .padding(.horizontal, DesignSystem.Spacing.small)
                .padding(.vertical, DesignSystem.Spacing.extraSmall)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DesignSystem.Color.yellow.opacity(0.12))
                )

            Rectangle()
                .fill(DesignSystem.Color.yellow.opacity(0.35))
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerRow5: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)
                .padding(.leading, DesignSystem.Spacing.extraSmall)

            HStack(spacing: 0) {


                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    // MARK: - Pick one icon for Today divider
                    //                    Image(systemName: "location.fill")
                    //                    Image(systemName: "mappin")
                    //                    Image(systemName: "scope")
                    //                    Image(systemName: "clock.fill")
//                    Image(systemName: "sun.max")
                    //                    Image(systemName: "sun.min")
                    //                    Image(systemName: "arrowtriangle.right.fill")
                    //                    Image(systemName: "chevron.right")
                    //                    Image(systemName: "smallcircle.filled.circle")
                    //                    Image(systemName: "diamond.fill")
                    //                    Image(systemName: "star.fill")
//                        .font(.system(size: 10))
//                        .foregroundStyle(DesignSystem.Color.yellow)
                    Text("Today")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DesignSystem.Color.yellow)

                    Rectangle()
                        .fill(DesignSystem.Color.yellow.opacity(0.15))
                        .frame(height: 1)
                        .padding(.leading, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerRow6: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)

            Rectangle()
                .fill(DesignSystem.Color.yellow)
                .frame(width: 2, height: 18)

            Text("Today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignSystem.Color.yellow)

            Capsule()
                .stroke(
                    DesignSystem.Color.yellow.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerRow7: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            CalendarCompactDateStamp(date: date, accentColor: DesignSystem.Color.yellow)

            HStack(spacing: DesignSystem.Spacing.extraSmall) {
                Rectangle()
                    .fill(DesignSystem.Color.yellow)
                    .frame(width: 3, height: 16)

                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.yellow)
                    .padding(.trailing, DesignSystem.Spacing.small)
            }
            .padding(.vertical, DesignSystem.Spacing.extraSmall)
            .padding(.leading, DesignSystem.Spacing.extraSmall)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DesignSystem.Color.yellow.opacity(0.12))
            )

            Rectangle()
                .fill(DesignSystem.Color.yellow.opacity(0.35))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerCardRow: View {
    let date: Date

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            CalendarCompactDateStamp(date: date, accentColor: .brown)
                .padding(.leading, DesignSystem.Spacing.extraSmall)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.extraSmall) {
                HStack(spacing: DesignSystem.Spacing.extraSmall) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 10))
                        .foregroundStyle(.brown)
                    Text("Today")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.brown)
                }

//                Rectangle()
//                    .fill(DesignSystem.Color.yellow.opacity(0.25))
//                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .calendarCardStyle(indicatorColor: .brown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

struct CalendarTodayDividerRow8: View {
    let date: Date

    var body: some View {
        HStack(spacing: 0) {
            CalendarFilledDateStamp(date: date, color: DesignSystem.Color.yellow)

            Rectangle()
                .fill(DesignSystem.Color.yellow.opacity(0.35))
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today"))
    }
}

#Preview("All Rows") {
    let sampleDate = Date()
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            CalendarTodayDividerRow(date: sampleDate)
            CalendarTodayDividerRow2(date: sampleDate)
            CalendarTodayDividerRow3(date: sampleDate)
            CalendarTodayDividerRow4(date: sampleDate)
            CalendarTodayDividerRow5(date: sampleDate)
            CalendarTodayDividerRow6(date: sampleDate)
            CalendarTodayDividerRow7(date: sampleDate)
            CalendarTodayDividerCardRow(date: sampleDate)
            CalendarTodayDividerRow8(date: sampleDate)
        }
        .padding()
    }
    .background(DesignSystem.Color.background)
}

