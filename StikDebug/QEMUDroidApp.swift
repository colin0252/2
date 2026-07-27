import SwiftUI

@main
struct QEMUDroidApp: App {
    @StateObject private var vmManager = VMManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vmManager)
                .onAppear {
                    vmManager.prepareImageAndStart()
                }
        }
    }
}
