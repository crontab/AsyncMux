//
//  AsyncMuxDemoApp.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import SwiftUI
import AsyncMux

@main
struct AsyncMuxDemoApp: App {
    @Environment(\.scenePhase) var scenePhase

    init() {
        NetworkMonitor.start()
    }

    var body: some Scene {
        scene()
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                    case .background:
                        Task {
                            await MuxRepository.saveAll()
                        }
                    case .inactive:
                        break
                    case .active:
                        break
                    @unknown default:
                        break
                }
            }
    }

    func scene() -> some Scene {
#if os(iOS)
        WindowGroup {
            ContentView()
        }
#else
        Window("AsyncMux Demo", id: String(describing: self)) {
            ContentView()
        }
#endif
    }
}
