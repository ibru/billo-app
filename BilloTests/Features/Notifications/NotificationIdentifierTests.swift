//  Created by Jiri Urbasek on 12/02/25.

import Testing
import Foundation
@testable import Billo

@Suite("NotificationIdentifier")
@MainActor
struct NotificationIdentifierTests {

    @Suite("stringValue")
    @MainActor
    struct StringValue {
        @Test
        func whenCreated_thenStringValueHasCorrectFormat() {
            let identifier = NotificationIdentifier(
                billIDHash: "a1b2c3d4e5f6",
                occurrenceTimestamp: 1234567890,
                offsetDays: 3
            )

            #expect(identifier.stringValue == "billo.r.a1b2c3d4e5f6_1234567890_3")
        }

        @Test
        func whenMultipleIdentifiers_thenEachHasUniqueStringValue() {
            let id1 = NotificationIdentifier(
                billIDHash: "abc123",
                occurrenceTimestamp: 1000,
                offsetDays: 0
            )

            let id2 = NotificationIdentifier(
                billIDHash: "abc123",
                occurrenceTimestamp: 2000,
                offsetDays: 0
            )

            let id3 = NotificationIdentifier(
                billIDHash: "abc123",
                occurrenceTimestamp: 1000,
                offsetDays: 3
            )

            #expect(id1.stringValue != id2.stringValue)
            #expect(id1.stringValue != id3.stringValue)
            #expect(id2.stringValue != id3.stringValue)
        }

        @Test
        func whenCreated_thenStringValueIsUnder64Characters() {
            // Test with maximum-length hash (12 chars) and large timestamp
            let identifier = NotificationIdentifier(
                billIDHash: "123456789abc",
                occurrenceTimestamp: 999999999999,
                offsetDays: 7
            )

            #expect(identifier.stringValue.count < 64)
        }
    }

    @Suite("parse")
    @MainActor
    struct Parse {
        @Test
        func whenValidString_thenParsesCorrectly() {
            let original = NotificationIdentifier(
                billIDHash: "a1b2c3d4e5f6",
                occurrenceTimestamp: 1234567890,
                offsetDays: 3
            )

            let parsed = NotificationIdentifier.parse(original.stringValue)

            #expect(parsed?.billIDHash == original.billIDHash)
            #expect(parsed?.occurrenceTimestamp == original.occurrenceTimestamp)
            #expect(parsed?.offsetDays == original.offsetDays)
        }

        @Test
        func whenInvalidPrefix_thenReturnsNil() {
            #expect(NotificationIdentifier.parse("invalid.prefix.abc_123_3") == nil)
        }

        @Test
        func whenMissingComponents_thenReturnsNil() {
            #expect(NotificationIdentifier.parse("billo.r.abc") == nil)
            #expect(NotificationIdentifier.parse("billo.r.abc_123") == nil)
        }

        @Test
        func whenEmptyString_thenReturnsNil() {
            #expect(NotificationIdentifier.parse("") == nil)
        }

        @Test
        func whenInvalidTimestamp_thenReturnsNil() {
            #expect(NotificationIdentifier.parse("billo.r.abc_notanumber_3") == nil)
        }

        @Test
        func whenInvalidOffset_thenReturnsNil() {
            #expect(NotificationIdentifier.parse("billo.r.abc_123_notanumber") == nil)
        }
    }

    @Suite("shortHash")
    @MainActor
    struct ShortHash {
        @Test
        func whenSameInput_thenProducesSameHash() {
            let input = "x-coredata://test/Bill/p123"

            let hash1 = NotificationIdentifier.shortHash(of: input)
            let hash2 = NotificationIdentifier.shortHash(of: input)

            #expect(hash1 == hash2)
        }

        @Test
        func whenDifferentInputs_thenProducesDifferentHashes() {
            let hash1 = NotificationIdentifier.shortHash(of: "input1")
            let hash2 = NotificationIdentifier.shortHash(of: "input2")

            #expect(hash1 != hash2)
        }

        @Test
        func whenCreated_thenHashIs12Characters() {
            let hash = NotificationIdentifier.shortHash(of: "any string")

            #expect(hash.count == 12)
        }

        @Test
        func whenCreated_thenHashContainsOnlyHexCharacters() {
            let hash = NotificationIdentifier.shortHash(of: "test")
            let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdef")

            #expect(hash.allSatisfy { char in
                hexCharacterSet.contains(char.unicodeScalars.first!)
            })
        }
    }

    @Suite("prefix")
    @MainActor
    struct Prefix {
        @Test
        func whenHashProvided_thenReturnsCorrectPrefix() {
            let hash = "a1b2c3d4e5f6"
            let prefix = NotificationIdentifier.prefix(forBillIDHash: hash)

            #expect(prefix == "billo.r.a1b2c3d4e5f6_")
        }

        @Test
        func whenIdentifierCreated_thenStringValueStartsWithCorrectPrefix() {
            let hash = "abc123"
            let identifier = NotificationIdentifier(
                billIDHash: hash,
                occurrenceTimestamp: 999,
                offsetDays: 0
            )

            let prefix = NotificationIdentifier.prefix(forBillIDHash: hash)

            #expect(identifier.stringValue.hasPrefix(prefix))
        }
    }

    @Suite("Equatable")
    @MainActor
    struct EquatableTests {
        @Test
        func whenIdentical_thenEqual() {
            let id1 = NotificationIdentifier(
                billIDHash: "abc",
                occurrenceTimestamp: 123,
                offsetDays: 3
            )

            let id2 = NotificationIdentifier(
                billIDHash: "abc",
                occurrenceTimestamp: 123,
                offsetDays: 3
            )

            #expect(id1 == id2)
        }

        @Test
        func whenDifferentHash_thenNotEqual() {
            let id1 = NotificationIdentifier(billIDHash: "abc", occurrenceTimestamp: 123, offsetDays: 3)
            let id2 = NotificationIdentifier(billIDHash: "xyz", occurrenceTimestamp: 123, offsetDays: 3)

            #expect(id1 != id2)
        }

        @Test
        func whenDifferentTimestamp_thenNotEqual() {
            let id1 = NotificationIdentifier(billIDHash: "abc", occurrenceTimestamp: 123, offsetDays: 3)
            let id2 = NotificationIdentifier(billIDHash: "abc", occurrenceTimestamp: 456, offsetDays: 3)

            #expect(id1 != id2)
        }

        @Test
        func whenDifferentOffset_thenNotEqual() {
            let id1 = NotificationIdentifier(billIDHash: "abc", occurrenceTimestamp: 123, offsetDays: 3)
            let id2 = NotificationIdentifier(billIDHash: "abc", occurrenceTimestamp: 123, offsetDays: 5)

            #expect(id1 != id2)
        }
    }

    @Suite("Constants")
    @MainActor
    struct Constants {
        @Test
        func whenDigestIdentifierForDate_thenUsesPrefix() {
            let calendar = Calendar(identifier: .gregorian)
            let date = Date(timeIntervalSinceReferenceDate: 0)
            let identifier = NotificationIdentifier.digestIdentifier(for: date, calendar: calendar)

            #expect(identifier.hasPrefix(NotificationIdentifier.digestPrefix))
        }

        @Test
        func whenIsDigestIdentifier_thenMatchesLegacyAndNew() {
            let calendar = Calendar(identifier: .gregorian)
            let date = Date(timeIntervalSinceReferenceDate: 0)
            let newIdentifier = NotificationIdentifier.digestIdentifier(for: date, calendar: calendar)

            #expect(NotificationIdentifier.isDigestIdentifier(NotificationIdentifier.legacyDigestIdentifier))
            #expect(NotificationIdentifier.isDigestIdentifier(newIdentifier))
        }
    }
}
