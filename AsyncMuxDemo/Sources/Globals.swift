//
//  Globals.swift
//
//  Created by Hovik Melikyan on 07/01/2023.
//

import Foundation


final class Globals {

    static var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

}
