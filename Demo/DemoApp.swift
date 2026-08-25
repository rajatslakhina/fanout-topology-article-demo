//  DemoApp.swift
//  Runnable host for FanOutPlannerUI. Open Demo.xcodeproj, pick a Simulator, Run.

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
