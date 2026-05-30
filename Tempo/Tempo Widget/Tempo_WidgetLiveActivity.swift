//
//  Tempo_WidgetLiveActivity.swift
//  Tempo Widget
//
//  Created by Charles Wang on 5/29/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Tempo_WidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Tempo_WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Tempo_WidgetAttributes.self) { context in
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

extension Tempo_WidgetAttributes {
    fileprivate static var preview: Tempo_WidgetAttributes {
        Tempo_WidgetAttributes(name: "World")
    }
}

extension Tempo_WidgetAttributes.ContentState {
    fileprivate static var smiley: Tempo_WidgetAttributes.ContentState {
        Tempo_WidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Tempo_WidgetAttributes.ContentState {
         Tempo_WidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Tempo_WidgetAttributes.preview) {
   Tempo_WidgetLiveActivity()
} contentStates: {
    Tempo_WidgetAttributes.ContentState.smiley
    Tempo_WidgetAttributes.ContentState.starEyes
}
