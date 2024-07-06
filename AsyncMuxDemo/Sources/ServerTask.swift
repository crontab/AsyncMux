//
//  ServerTask.swift
//
//  Created by Hovik Melikyan on 08/01/2023.
//

import SwiftUI


extension View {

    func serverTask(withAlert: Bool = true, _ action: @escaping () async throws -> Void) -> some View {
        modifier(TaskModifier(withAlert: withAlert, action: action))
    }

    @ViewBuilder
    func serverRefreshable(withAlert: Bool = true, _ action: @escaping () async throws -> Void) -> some View {
        modifier(RefreshableModifier(withAlert: withAlert, action: action))
    }
}


private struct TaskModifier: ViewModifier {

    let withAlert: Bool
    let action: () async throws -> Void
    @State private var error: Error?
    
    func body(content: Content) -> some View {
        content.task {
            guard !Globals.isPreview else { return }
            do {
                try await action()
            }
            catch {
                if withAlert {
                    self.error = error
                }
            }
        }
        .errorAlert($error)
    }
}


private struct RefreshableModifier: ViewModifier {

    let withAlert: Bool
    let action: () async throws -> Void
    @State private var error: Error?

    func body(content: Content) -> some View {
        content.refreshable {
            guard !Globals.isPreview else { return }
            do {
                try await action()
            }
            catch {
                if withAlert {
                    self.error = error
                }
            }
        }
        .errorAlert($error)
    }
}
