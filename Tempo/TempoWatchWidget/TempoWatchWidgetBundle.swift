//
//  TempoWatchWidgetBundle.swift
//  TempoWatchWidget
//
//  Created by Charles Wang on 6/2/26.
//

import WidgetKit
import SwiftUI

@main
struct TempoWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        ActiveSessionWidget()
        SuggestedTimerWidget()
        QuickStartWidget()
    }
}
