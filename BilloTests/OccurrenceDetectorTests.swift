//  Created by Jiri Urbasek on 11/28/25.

import Testing
import Foundation
@testable import Billo

@Suite("OccurrenceDetector")
struct OccurrenceDetectorTests {

    @Suite("Single Candidate")
    struct SingleCandidate {
        @Test func whenOnlyOneUnpaidOccurrence_thenDetectsCertain() {
            let sut = makeSUT()
            let oct4 = makeDate(month: 10, day: 4)

            let result = sut.detectOccurrence(for: makeDate(month: 10, day: 1), from: [oct4])

            guard case .certain(let detected) = result else {
                Issue.record("Expected certain detection")
                return
            }
            #expect(detected == oct4)
        }
    }

    @Suite("Single Future (No Distance Limit)")
    struct SingleFuture {
        @Test func whenSingleFutureAndNoOverdue_thenDetectsRegardlessOfDistance() {
            let sut = makeSUT()
            let oct4 = makeDate(month: 10, day: 4)

            let result = sut.detectOccurrence(for: makeDate(month: 6, day: 1), from: [oct4])

            guard case .certain(let detected) = result else {
                Issue.record("Expected certain detection")
                return
            }
            #expect(detected == oct4)
        }
    }

    @Suite("Next Occurrence (Multiple Future)")
    struct NextOccurrence {
        @Test func whenMultipleFutureWithinTwoWeeks_thenChoosesNearest() {
            let sut = makeSUT()
            let oct4 = makeDate(month: 10, day: 4)
            let nov4 = makeDate(month: 11, day: 4)

            let result = sut.detectOccurrence(for: makeDate(month: 9, day: 25), from: [oct4, nov4])

            guard case .certain(let detected) = result else {
                Issue.record("Expected certain detection")
                return
            }
            #expect(detected == oct4)
        }
    }

    @Suite("Recent Overdue")
    struct RecentOverdue {
        @Test func whenSingleOverdueWithinWeek_thenChoosesOverdue() {
            let sut = makeSUT()
            let sept4 = makeDate(month: 9, day: 4)
            let oct4 = makeDate(month: 10, day: 4)

            let result = sut.detectOccurrence(for: makeDate(month: 9, day: 10), from: [sept4, oct4])

            guard case .certain(let detected) = result else {
                Issue.record("Expected certain detection")
                return
            }
            #expect(detected == sept4)
        }
    }

    @Suite("Close Proximity")
    struct CloseProximity {
        @Test func whenSingleOccurrenceWithinWeekEitherSide_thenChoosesIt() {
            let sut = makeSUT()
            let oct4 = makeDate(month: 10, day: 4)
            let nov4 = makeDate(month: 11, day: 4)

            let result = sut.detectOccurrence(for: makeDate(month: 10, day: 8), from: [oct4, nov4])

            guard case .certain(let detected) = result else {
                Issue.record("Expected certain detection")
                return
            }
            #expect(detected == oct4)
        }
    }

    @Suite("Edge Cases")
    struct EdgeCases {
        @Test func whenNoUnpaidOccurrences_thenReturnsNoneUnpaid() {
            let sut = makeSUT()

            let result = sut.detectOccurrence(for: makeDate(month: 10, day: 1), from: [])

            guard case .noneUnpaid = result else {
                Issue.record("Expected noneUnpaid")
                return
            }
        }

        @Test func whenMultipleOverdue_thenAmbiguous() {
            let sut = makeSUT()
            let aug4 = makeDate(month: 8, day: 4)
            let sept4 = makeDate(month: 9, day: 4)

            let result = sut.detectOccurrence(for: makeDate(month: 10, day: 1), from: [aug4, sept4])

            guard case .ambiguous(let candidates) = result else {
                Issue.record("Expected ambiguous")
                return
            }
            #expect(candidates.count == 2)
        }

        @Test func whenEquidistantFutureAndPastWithinWindow_thenChoosesRecentOverdue() {
            let sut = makeSUT()
            let past = makeDate(month: 9, day: 1)
            let future = makeDate(month: 9, day: 13)

            let result = sut.detectOccurrence(for: makeDate(month: 9, day: 7), from: [past, future])

            guard case .certain(let detected) = result else {
                Issue.record("Expected choosing recent overdue when equidistant")
                return
            }
            #expect(detected == past)
        }

        @Test func whenPaymentSameDayButDifferentTime_thenTreatsAsSameDay() {
            let sut = makeSUT()
            let oct4Morning = makeDate(month: 10, day: 4, hour: 8)
            let oct4Evening = makeDate(month: 10, day: 4, hour: 20)

            let result = sut.detectOccurrence(for: oct4Evening, from: [oct4Morning])

            guard case .certain(let detected) = result else {
                Issue.record("Expected certain detection")
                return
            }
            #expect(Calendar.current.isDate(detected, inSameDayAs: oct4Evening))
        }
    }
}

// MARK: - makeSUT & Factories

private func makeSUT() -> OccurrenceDetector {
    OccurrenceDetector(calendar: .current)
}

private func makeDate(
    year: Int = 2025,
    month: Int,
    day: Int,
    hour: Int = 12
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return Calendar.current.date(from: components)!
}
