//
//  AppIntent.swift
//  SomaWidgets
//
//  Created by Prasuk Jain on 17/03/2026.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Soma Metrics" }
    static var description: IntentDescription { "Display your health and recovery metrics." }
}
