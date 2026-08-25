//  DemoApp.swift
//  Host app for FanOutPlannerUI: open Demo.xcodeproj, pick a Simulator, Build & Run.
//  Not covered by `swift build` — see the README's Verification status before trusting it.

import SwiftUI
import FanOutPlannerUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            FanOutPlannerView()
        }
    }
}
