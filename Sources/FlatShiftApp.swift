import SwiftUI

@main
struct FlatShiftApp: App {
    @StateObject private var shiftStore = ShiftStore()
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(shiftStore)
                .environmentObject(store)
                .preferredColorScheme(shiftStore.preferences.appearanceMode.preferredColorScheme)
        }
    }
}
