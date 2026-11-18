#!/bin/bash
# Renders the wide home screen widget to a PNG on macOS (used by the screenshots workflow).
# Usage: Tools/widget-preview/render.sh <output.png>
set -euo pipefail
out="$1"
work=$(mktemp -d)
{
  cat <<'SWIFT'
import SwiftUI
import WidgetKit
import AppKit

struct PulseEntry {
    let date: Date
    let score: Int?
    let zone: String
    let sleepPerformance: Double?
    let strain: Double?
    let strainTarget: Double?
}

func zoneColor(_ zone: String) -> Color {
    switch zone {
    case "green": return Color(red: 0.184, green: 0.839, blue: 0.451)
    case "yellow": return Color(red: 0.961, green: 0.773, blue: 0.259)
    case "red": return Color(red: 0.937, green: 0.325, blue: 0.314)
    default: return Color(red: 0.54, green: 0.59, blue: 0.65)
    }
}
SWIFT
  # The widget view itself, copied from the widget source.
  awk '/^struct ScoresWidgetView/{p=1} /^struct PulseScoresWidget/{p=0} p' PulseWidget/PulseWidget.swift
  cat <<'SWIFT'

@MainActor
func render(_ entry: PulseEntry, to path: String) {
    let view = ScoresWidgetView(entry: entry)
        .padding(16)
        .frame(width: 364, height: 170)
        .background(Color(red: 0.133, green: 0.153, blue: 0.176))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(20)
        .background(Color(red: 0.62, green: 0.85, blue: 0.86))
        .environment(\.colorScheme, .dark)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    guard let image = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

MainActor.assumeIsolated {
    render(PulseEntry(date: Date(), score: 68, zone: "green", sleepPerformance: 89, strain: 12.4, strainTarget: 14), to: CommandLine.arguments[1])
}
SWIFT
} > "$work/main.swift"
xcrun swiftc -O -o "$work/render" "$work/main.swift"
"$work/render" "$out"
