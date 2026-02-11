//
//  NudgeWidgetBundle.swift
//  NudgeWidgetExtension
//
//  Widget extension entry point — provides all widget configurations:
//    • NudgeLiveActivityWidget — Dynamic Island + Lock Screen Live Activity
//    • NudgeHomeWidget         — Home Screen (small + medium)
//    • NudgeLockScreenWidget   — Lock Screen (circular + rectangular)
//
//  This target must be added in Xcode: File → New → Target → Widget Extension.
//

import WidgetKit
import SwiftUI

@main
struct NudgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        NudgeLiveActivityWidget()
        NudgeHomeWidget()
        NudgeLockScreenWidget()
    }
}
