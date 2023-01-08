//
//  ErrorAlert.swift
//
//  Created by Hovik Melikyan on 08/01/2023.
//

import SwiftUI


extension View {

	func errorAlert(_ error: Binding<Error?>) -> some View {
		let value = error.wrappedValue
		return alert("Oops...", isPresented: .constant(value != nil)) {
			Button("OK") {
				error.wrappedValue = nil
			}
		} message: {
			Text(value?.localizedDescription ?? "Unknown error")
		}
	}
}
