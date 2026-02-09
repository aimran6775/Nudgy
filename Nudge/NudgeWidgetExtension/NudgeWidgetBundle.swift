//
//  NudgeWidgetBundle.swift
//  NudgeWidgetExtension
//
//  Widget extension entry point — provides the Live Activity configuration.
//  This target must be added in Xcode: File → New → Target → Widget Extension.
//

import WidgetKit
import SwiftUI

@main
struct NudgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        NudgeLiveActivityWidget()
    }
}
