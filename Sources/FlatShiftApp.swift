import SwiftUI

@main
struct FlatShiftApp: App {
    @StateObject private var shiftStore = ShiftStore()
    @StateObject private var store = StoreManager()
    @StateObject private var reviewManager = ReviewPromptManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(shiftStore)
                .environmentObject(store)
                .environmentObject(reviewManager)
                .preferredColorScheme(shiftStore.preferences.appearanceMode.preferredColorScheme)
        }
    }
}
