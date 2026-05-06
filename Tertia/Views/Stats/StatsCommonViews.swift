//
//  StatsCommonViews.swift
//  Tertia
//
//  Shared building blocks used by multiple Stats sections — section
//  headers, the small numeric tile, and the rounded chart-card chrome.
//  Section-specific subviews live alongside their owning section file.
//

import SwiftUI

struct SectionHeading: View {
    let title: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
    }
}

struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .imageScale(.small)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // `reservesSpace: true` keeps every tile two lines tall
                    // even when a label fits on one — without it, "Day streak"
                    // (1 line) renders shorter than "Best streak" / "Best
                    // score" (which wrap to 2 in narrow widths).
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(value)
                .font(.title.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
}

struct ChartCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            }
    }
}
