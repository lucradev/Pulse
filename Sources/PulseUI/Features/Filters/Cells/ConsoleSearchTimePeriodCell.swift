// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(macOS)

struct ConsoleSearchTimePeriodCell: View {
    @Binding var selection: ConsoleSearchCriteria.Dates

    var body: some View {
        DateRangePicker(title: "Start", date: $selection.startDate)
        DateRangePicker(title: "End", date: $selection.endDate)
        quickFilters
    }

    @ViewBuilder
    private var quickFilters: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Quick Filters")
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Recent") { selection = .recent }
            Button("Today") { selection = .today }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .foregroundColor(.blue)
    }
}

#endif
