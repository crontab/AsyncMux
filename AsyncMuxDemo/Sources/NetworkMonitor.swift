//
//  NetworkMonitor.swift
//  AsyncMuxDemo
//
//  Created by Hovik Melikyan on 25.06.25.
//

import Foundation
import Network


final class NetworkMonitor {

    static func start() {
        Task { @MainActor in
            for await path in monitor {
                print("Connection is:", path.debugDescription)
                // NWPath sends a lot of strange and even irrelevant statuses; the only way to make sense of it is to compare to the previous known status, and also to assume `.satisfied` at program startup so that the first event is not fired, as it's not necessary.
                if path.status != lastStatus {
                    lastStatus = path.status
                    NotificationCenter.default.post(name: .networkDidChangeStatus, object: path.status == .satisfied)
                }
            }
        }
    }

    @MainActor
    private static var lastStatus: NWPath.Status = .satisfied

    private static let monitor = NWPathMonitor()
}


extension Notification.Name {
    static let networkDidChangeStatus = Self("networkDidChangeStatus") // arg = Bool
}
