//
//  SomaWidgetsLiveActivity.swift
//  SomaWidgets
//
//  Created by Prasuk Jain on 17/03/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SomaWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SomaWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SomaWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SomaWidgetsAttributes {
    fileprivate static var preview: SomaWidgetsAttributes {
        SomaWidgetsAttributes(name: "World")
    }
}

extension SomaWidgetsAttributes.ContentState {
    fileprivate static var smiley: SomaWidgetsAttributes.ContentState {
        SomaWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SomaWidgetsAttributes.ContentState {
         SomaWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SomaWidgetsAttributes.preview) {
   SomaWidgetsLiveActivity()
} contentStates: {
    SomaWidgetsAttributes.ContentState.smiley
    SomaWidgetsAttributes.ContentState.starEyes
}
