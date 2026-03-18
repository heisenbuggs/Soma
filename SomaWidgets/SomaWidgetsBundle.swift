//
//  SomaWidgetsBundle.swift
//  SomaWidgets
//
//  Created by Prasuk Jain on 17/03/2026.
//

import WidgetKit
import SwiftUI

@main
struct SomaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SomaWidgets()
        SomaWidgetsControl()
        SomaWidgetsLiveActivity()
    }
}
