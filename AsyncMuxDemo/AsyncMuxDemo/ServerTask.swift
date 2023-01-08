//
//  ServerTask.swift
//
//  Created by Hovik Melikyan on 08/01/2023.
//

import SwiftUI


extension View {

	func serverTask(_ action: @escaping () async throws -> Void) -> some View {
		modifier(Modifier(action: action))
	}
}


private struct Modifier: ViewModifier {

	let action: () async throws -> Void
	@State private var error: Error?

	func body(content: Content) -> some View {
		content.task {
			guard !Globals.isPreview else { return }
			do {
				try await action()
			}
			catch {
				self.error = error
			}
		}
		.errorAlert($error)
	}
}
