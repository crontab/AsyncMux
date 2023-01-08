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
		WindowGroup {
			ContentView()
		}
		.onChange(of: scenePhase) { newPhase in
			switch newPhase {
				case .background:
					MuxRepository.saveAll()
				case .inactive:
					break
				case .active:
					break
				@unknown default:
					break
			}
		}
	}
}
