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

    var body: some Scene {
        scene()
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                    case .background:
                        Task {
                            await MuxRepository.shared.saveAll()
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
