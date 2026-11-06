import CoreGraphics
import Foundation
import SwiftData

/// Seed boards and notes for debug builds and previews: "Home", listed first, whose notes are
/// placed to fit the smallest iPhone in portrait, overlapping a little so stacking order can
/// be seen; and "Work", with one note.
///
/// Not `#if DEBUG`, since previews use it and Release builds compile previews too; the app seeds
/// a store with it only in Debug.
public enum SampleData {
    public static func seedIfEmpty(in context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Note>())) ?? 0) == 0 else { return }
        seed(in: context)
    }

    public static func seed(in context: ModelContext) {
        let home = Board(name: "Home")
        let work = Board(name: "Work")
        // Created in the same instant, they would list in no particular order.
        work.createdAt = home.createdAt.addingTimeInterval(1)
        context.insert(home)
        context.insert(work)

        let seeds: [(String, CGPoint, NoteColor, Board)] = [
            ("Buy oat milk", CGPoint(x: 100, y: 180), .yellow, home),
            ("Call the dentist before Friday", CGPoint(x: 250, y: 260), .pink, home),
            ("Ideas for the weekend:\nhike, bake bread", CGPoint(x: 120, y: 420), .blue, home),
            ("", CGPoint(x: 260, y: 540), .green, home),
            ("Book the team offsite", CGPoint(x: 140, y: 220), .yellow, work),
        ]
        for (z, seed) in seeds.enumerated() {
            let note = Note(center: seed.1, color: seed.2, z: z, text: seed.0)
            context.insert(note)
            note.board = seed.3
        }
        try? context.save()
    }

    public static func seedListingIfEmpty(in context: ModelContext) {
        guard ((try? context.fetchCount(FetchDescriptor<Note>())) ?? 0) == 0 else { return }
        seedListing(in: context)
    }

    /// The boards the App Store listing photographs (`Screenshots/` in the app's repository):
    /// "Home", opened at launch, and "Lisbon", laid out so the top-left 440 × 800 points (a large
    /// iPhone's canvas) is a board of its own and the rest fills the 700 × 1300 a 13-inch iPad's
    /// list of boards leaves it in portrait; "Work", for the list and the search; and
    /// "Groceries", empty, for Make Notes to fill. Every color is on "Home", Pro's included.
    public static func seedListing(in context: ModelContext) {
        let names = ["Home", "Work", "Lisbon", "Groceries"]
        let start = Date.now
        let boards = names.enumerated().map { index, name in
            let board = Board(name: name)
            board.createdAt = start.addingTimeInterval(Double(index))
            context.insert(board)
            return board
        }
        let (home, work, lisbon) = (boards[0], boards[1], boards[2])

        let seeds: [(String, CGPoint, Double, NoteColor, Board)] = [
            ("Pick up the dry cleaning", CGPoint(x: 104, y: 100), 168, .yellow, home),
            ("Call Mum\nSunday, 6pm", CGPoint(x: 316, y: 120), 160, .pink, home),
            (
                "Weekend\n· farmers market\n· bike to the lake\n· finish the puzzle",
                CGPoint(x: 140, y: 330), 228, .blue, home
            ),
            ("Water the basil", CGPoint(x: 350, y: 318), 132, .green, home),
            ("Book the dentist before Friday", CGPoint(x: 326, y: 528), 168, .orange, home),
            (
                "Gift ideas for Sam: a record player, a really good pen",
                CGPoint(x: 116, y: 590), 196, .purple, home
            ),
            ("Return the library books", CGPoint(x: 330, y: 742), 160, .teal, home),
            ("Wi-Fi: Oakhouse\nPassword on the fridge", CGPoint(x: 600, y: 115), 180, .gray, home),
            (
                "Dinner Friday\nLasagne\nSalad\nThat lemon cake", CGPoint(x: 590, y: 330), 200,
                .yellow, home
            ),
            ("Renew passport!", CGPoint(x: 610, y: 535), 150, .pink, home),
            ("Fix the squeaky gate", CGPoint(x: 585, y: 720), 160, .teal, home),
            ("Plumber Tuesday 8–10", CGPoint(x: 120, y: 900), 170, .orange, home),
            (
                "Ideas for the weekend away: the coast, or the lakes?", CGPoint(x: 350, y: 980),
                210, .blue, home
            ),
            ("Pay the council tax", CGPoint(x: 610, y: 900), 150, .yellow, home),
            ("Order more coffee beans", CGPoint(x: 590, y: 1085), 170, .gray, home),
            ("Book a table for Ana's birthday", CGPoint(x: 120, y: 1120), 180, .pink, home),
            (
                "Garden: sweet peas, tomatoes, a bench under the apple tree",
                CGPoint(x: 370, y: 1200), 220, .green, home
            ),

            ("Book the team offsite", CGPoint(x: 120, y: 120), 180, .yellow, work),
            ("Q3 roadmap review\nThursday 2pm", CGPoint(x: 320, y: 160), 170, .blue, work),
            ("Reply to Priya about the launch", CGPoint(x: 140, y: 360), 170, .pink, work),
            ("Draft the newsletter", CGPoint(x: 330, y: 400), 150, .green, work),

            ("Pastéis de Belém, early", CGPoint(x: 110, y: 110), 170, .orange, lisbon),
            ("Tram 28 before 9", CGPoint(x: 320, y: 140), 160, .yellow, lisbon),
            ("Bookshop: Livraria Bertrand", CGPoint(x: 150, y: 340), 180, .teal, lisbon),
            ("Sunset at the Miradouro da Graça", CGPoint(x: 345, y: 370), 170, .pink, lisbon),
            (
                "Day trip to Sintra\nPena Palace, Quinta da Regaleira", CGPoint(x: 130, y: 580),
                210, .blue, lisbon
            ),
            ("Pack the adapter!", CGPoint(x: 350, y: 560), 140, .gray, lisbon),
            ("Fado on Thursday: get tickets", CGPoint(x: 330, y: 760), 170, .purple, lisbon),
            ("Time Out Market for lunch", CGPoint(x: 590, y: 120), 170, .green, lisbon),
            ("Learn: obrigado, obrigada", CGPoint(x: 600, y: 330), 150, .yellow, lisbon),
            ("LX Factory on Sunday", CGPoint(x: 585, y: 530), 160, .orange, lisbon),
            ("Flight TP1351\nFri 7:40", CGPoint(x: 600, y: 740), 170, .blue, lisbon),
            ("Postcards for Gran", CGPoint(x: 120, y: 860), 150, .pink, lisbon),
            ("Ginjinha in a chocolate cup", CGPoint(x: 350, y: 970), 160, .purple, lisbon),
            ("Home Tuesday, taxi at 6", CGPoint(x: 590, y: 960), 170, .teal, lisbon),
        ]
        for (z, seed) in seeds.enumerated() {
            let note = Note(center: seed.1, color: seed.3, z: z, text: seed.0)
            note.side = seed.2
            context.insert(note)
            note.board = seed.4
        }
        try? context.save()
    }
}
