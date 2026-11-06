import LaunchArguments
import NoteModel
import OSLog
import SwiftData
import SwiftUI

@main
struct StickyNotesApp: App {
    private let container: ModelContainer
    @State private var store: NoteStore
    @State private var tourStage = TourStage()
    @State private var pro = Pro()
    @Environment(\.scenePhase) private var phase
    private var tour = OnboardingProgress()

    init() {
        let container = Self.openStore()
        self.container = container
        let store = NoteStore(context: container.mainContext)
        store.actionName = \.undoName
        store.firstBoard(
            creatingOneNamed: String(
                localized: "My Board", comment: "The name of the board made on first launch."))
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            BoardsView()
                .stagesTheTour()
                .watchesTheStore(pro)
                .environment(store)
                .environment(tourStage)
                .environment(pro)
        }
        .modelContainer(container)
        .defaultSize(width: 960, height: 720)
        // Typing saves once it pauses; leaving the foreground saves it now. So does quitting on a
        // Mac, which moves the app to the background before it exits.
        .onChange(of: phase) { _, phase in
            if phase != .active { store.saveText() }
        }
        // In the Help menu of the Mac, and of an iPad's menu bar. Replaces the default item, since
        // there is no help book.
        .commands {
            CommandGroup(replacing: .help) {
                Button {
                    tour.markDue()
                } label: {
                    Text(
                        "Sticky Notes Tour",
                        comment: "The Help menu item that puts the tour of the gestures back up.")
                }
            }
            ProCommands(pro: pro)
        }
    }

    private static func openStore() -> ModelContainer {
        // The unit tests are hosted in this process, and must not touch the reader's notes.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return memoryFallback()
        }

        let container: ModelContainer
        if LaunchFlag.ephemeralStore.isPresent() {
            container = memoryFallback()
        } else {
            do {
                container = try .onDisk()
            } catch {
                Logger.store.critical("On-disk store wouldn't open, running from memory: \(error)")
                container = memoryFallback()
            }
        }

        #if DEBUG
            if LaunchFlag.seedListing.isPresent() {
                SampleData.seedListingIfEmpty(in: container.mainContext)
            } else if LaunchFlag.seedStore.isPresent() {
                SampleData.seedIfEmpty(in: container.mainContext)
            }
        #endif

        return container
    }

    /// Traps if even an in-memory container fails, which means the schema itself is invalid.
    private static func memoryFallback() -> ModelContainer {
        do {
            return try .inMemory()
        } catch {
            fatalError("Could not create a model container: \(error)")
        }
    }
}

extension Logger {
    fileprivate static let store = Logger(
        subsystem: "com.thebinarykitchen.StickyNotes", category: "store")
}
