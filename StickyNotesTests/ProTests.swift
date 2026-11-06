import AccessibilityIdentifiers
import Foundation
import LaunchArguments
import NoteModel
import Testing

@testable import StickyNotes

@Suite("Pro")
struct ProTests {
    @Test("Make Notes is allowed until this month's free runs are gone")
    func makeNotesRunsOut() {
        #expect(ProFeature.allowsMakeNotes(used: 0))
        #expect(ProFeature.allowsMakeNotes(used: ProFeature.freeMakeNotes - 1))
        #expect(!ProFeature.allowsMakeNotes(used: ProFeature.freeMakeNotes))
        #expect(!ProFeature.allowsMakeNotes(used: ProFeature.freeMakeNotes + 100))
    }

    /// Boards beyond the free ones — from before a refund — are kept, and still allow no more.
    @Test("Another board is allowed until the free ones are all in use")
    func boardsRunOut() {
        #expect(ProFeature.allowsAnotherBoard(having: 1))
        #expect(ProFeature.allowsAnotherBoard(having: ProFeature.freeBoards - 1))
        #expect(!ProFeature.allowsAnotherBoard(having: ProFeature.freeBoards))
        #expect(!ProFeature.allowsAnotherBoard(having: 7))
    }

    @Test("Only Make Notes is spent by the month")
    func onlyMakeNotesIsMonthly() {
        #expect(ProFeature.monthly == [.makeNotes])
    }

    @Test("Every feature has copy of its own", arguments: ProFeature.allCases)
    func everyFeatureIsExplained(feature: ProFeature) {
        #expect(!String(localized: feature.headline).isEmpty)
        #expect(!String(localized: feature.explanation).isEmpty)
        #expect(!String(localized: feature.offer).isEmpty)
        #expect(!String(localized: feature.allowance).isEmpty)
        #expect(!String(localized: feature.exhausted).isEmpty)
        #expect(!feature.symbol.isEmpty)
    }

    @Test("No two features say the same thing, or are drawn the same")
    func copyIsNotShared() {
        let headlines = Set(ProFeature.allCases.map { String(localized: $0.headline) })
        #expect(headlines.count == ProFeature.allCases.count)
        let symbols = Set(ProFeature.allCases.map(\.symbol))
        #expect(symbols.count == ProFeature.allCases.count)
    }

    /// The captions interpolate the counts, so unlike ``ProFeature/explanation`` they can't
    /// drift — this is what would catch one being spelled out again by hand.
    @Test("The cards' captions count what is actually free")
    func theCaptionsAgreeWithTheAllowances() {
        #expect(
            String(localized: ProFeature.makeNotes.allowance)
                .contains("\(ProFeature.freeMakeNotes)"))
        #expect(
            String(localized: ProFeature.boards.allowance).contains("\(ProFeature.freeBoards)"))
    }

    /// The counts are written twice — as constants and spelled out in the explanations — so
    /// the copy reads like English. This keeps the second copy honest when the first changes.
    @Test("The copy says the allowance it actually is")
    func theCopyAgreesWithTheAllowances() throws {
        let makeNotes = try #require(Self.spelledOut(ProFeature.freeMakeNotes))
        let boards = try #require(Self.spelledOut(ProFeature.freeBoards))
        // The key, not the resolved string: the source copy is English whatever the app runs in.
        #expect(ProFeature.makeNotes.explanation.key.lowercased().contains(makeNotes))
        #expect(ProFeature.boards.explanation.key.lowercased().contains(boards))
    }

    /// "ten", in the English the source copy is written in.
    private static func spelledOut(_ count: Int) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: count))?.lowercased()
    }

    /// The colors copy names the free ones and counts the rest.
    @Test("The colors copy agrees with the colors")
    func theColorsCopyAgreesWithTheColors() throws {
        let key = ProFeature.colors.explanation.key.lowercased()
        for color in NoteColor.handedOut {
            #expect(key.contains(color.rawValue), "\(color) is free but the copy doesn't say so")
        }
        let extra = NoteColor.allCases.count - NoteColor.handedOut.count
        #expect(key.contains(try #require(Self.spelledOut(extra))))
    }

    @Test("Make Notes counts under the key the UI tests preset")
    func theUsedKeyIsTheOneTheTestsPreset() {
        #expect(ProPreference.usedKey(.makeNotes) == LaunchDefault.proUsedMakeNotes.rawValue)
        #expect(ProPreference.unlockedKey == LaunchDefault.proUnlocked.rawValue)
        #expect(ProPreference.periodKey(.makeNotes) != ProPreference.usedKey(.makeNotes))
    }

    @Test("The identifiers package names every feature")
    func theTestsCanNameEveryFeature() {
        #expect(A11y.Pro.features == ProFeature.allCases.map(\.rawValue))
        #expect(!A11y.Pro.features.contains(A11y.Pro.listReason))
    }
}

/// Uses a fixed Gregorian GMT calendar, independent of the test machine's settings.
@Suite("The month an allowance belongs to")
struct ProPeriodTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private func stamp(year: Int, month: Int, day: Int = 1) throws -> Int {
        let components = DateComponents(year: year, month: month, day: day)
        let date = try #require(Self.calendar.date(from: components))
        return ProPeriod.stamp(for: date, in: Self.calendar)
    }

    @Test("A month is one number, whatever day of it you ask on")
    func aMonthIsOneNumber() throws {
        #expect(try stamp(year: 2026, month: 9, day: 1) == stamp(year: 2026, month: 9, day: 30))
    }

    @Test("The next month is the next number, and next year is not this one")
    func monthsAreConsecutive() throws {
        let september = try stamp(year: 2026, month: 9)
        #expect(try stamp(year: 2026, month: 10) == september + 1)
        #expect(try stamp(year: 2027, month: 1) == stamp(year: 2026, month: 12) + 1)
        #expect(try stamp(year: 2027, month: 9) != september)
    }

    @Test("A count is worth nothing to any month but its own")
    func aCountBelongsToItsOwnMonth() throws {
        let september = try stamp(year: 2026, month: 9)
        let october = try stamp(year: 2026, month: 10)
        #expect(ProPeriod.carried(10, stamped: september, into: september) == 10)
        #expect(ProPeriod.carried(10, stamped: september, into: october) == 0)
        #expect(ProPeriod.carried(9999, stamped: nil, into: september) == 0)
    }
}

/// ``Pro`` itself, with no StoreKit: what it allows locked and unlocked, and an allowance across
/// a month boundary it never saw an activation for.
@MainActor
@Suite("What Pro allows", .serialized)
struct ProAllowanceTests {
    private final class Clock {
        var period = ProPeriod.current
    }

    /// Runs `body` with no Pro state in defaults, and puts back what was there.
    private func withCleanDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let keys =
            [ProPreference.unlockedKey] + ProFeature.monthly.map(ProPreference.usedKey)
            + ProFeature.monthly.map(ProPreference.periodKey)
        let kept = keys.map { ($0, defaults.object(forKey: $0)) }
        keys.forEach(defaults.removeObject)
        defer {
            for (key, value) in kept { defaults.set(value, forKey: key) }
        }
        try body()
    }

    @Test("Locked, the free things are free and the rest ask")
    func lockedAllowsWhatIsFree() {
        withCleanDefaults {
            let pro = Pro()
            #expect(pro.allows(.makeNotes))
            #expect(!pro.allows(.boards))
            #expect(!pro.allows(.colors))
            #expect(pro.allowsAnotherBoard(having: ProFeature.freeBoards - 1))
            #expect(!pro.allowsAnotherBoard(having: ProFeature.freeBoards))
            for color in NoteColor.allCases {
                #expect(pro.allows(color) == NoteColor.handedOut.contains(color))
            }
        }
    }

    @Test("Spending boards or colors counts nothing")
    func onlyMonthlyFeaturesAreSpent() {
        withCleanDefaults {
            let pro = Pro()
            pro.spend(.boards)
            pro.spend(.colors)
            #expect(UserDefaults.standard.object(forKey: "pro.used.boards") == nil)
            #expect(UserDefaults.standard.object(forKey: "pro.used.colors") == nil)
        }
    }

    @Test("The run that spends the last free one is the one that runs out")
    func theLastRunRunsOut() {
        withCleanDefaults {
            let pro = Pro()
            for _ in 0..<(ProFeature.freeMakeNotes - 1) { pro.spend(.makeNotes) }
            #expect(pro.allows(.makeNotes))
            pro.spend(.makeNotes)
            #expect(pro.hasRunOut(of: .makeNotes))
            #expect(ProPreference.used(.makeNotes) == ProFeature.freeMakeNotes)
        }
    }

    @Test("A Make Notes allowance spent last month is back on the 1st without reactivating")
    func aNewMonthIsANewAllowance() {
        withCleanDefaults {
            let clock = Clock()
            let pro = Pro(period: { clock.period })
            for _ in 0..<ProFeature.freeMakeNotes { pro.spend(.makeNotes) }
            #expect(pro.hasRunOut(of: .makeNotes))

            clock.period += 1

            #expect(pro.allows(.makeNotes))
            pro.spend(.makeNotes)
            #expect(pro.allows(.makeNotes), "one use of the new month, not last month's plus one")
        }
    }
}
