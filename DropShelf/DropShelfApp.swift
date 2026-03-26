//
//  DropShelfApp.swift
//  DropShelf
//
//  Created by yc1314179 on 3/26/26.
//

import SwiftUI

@main
struct DropShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
