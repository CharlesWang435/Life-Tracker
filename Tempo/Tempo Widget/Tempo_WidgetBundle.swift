//
//  Tempo_WidgetBundle.swift
//  Tempo Widget
//
//  Created by Charles Wang on 5/29/26.
//

import WidgetKit
import SwiftUI

@main
struct Tempo_WidgetBundle: WidgetBundle {
    var body: some Widget {
        Tempo_Widget()
        Tempo_WidgetControl()
        Tempo_WidgetLiveActivity()
    }
}
