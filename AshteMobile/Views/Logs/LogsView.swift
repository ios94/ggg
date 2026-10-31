//
//  LogsView.swift
//  AshteMobile
//
//  Shows what the app is doing under the hood (signing, install, downloads).
//

import SwiftUI
import NimbleViews

struct LogsView: View {
	var body: some View {
		NBNavigationView(.localized("Logs")) {
			LogsListView()
		}
	}
}

/// The list itself, so it can also be pushed from Settings without a nested navigation stack.
struct LogsListView: View {
	@StateObject private var _logs = LogsManager.shared
	
	private static let _timeFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH:mm:ss"
		return f
	}()
	
	var body: some View {
		List {
			ForEach(_logs.entries.reversed()) { entry in
				HStack(alignment: .top, spacing: 10) {
					Image(systemName: entry.level.icon)
						.foregroundStyle(entry.level.color)
						.frame(width: 22)
					
					VStack(alignment: .leading, spacing: 3) {
						Text(entry.message)
							.font(.system(.footnote, design: .monospaced))
							.textSelection(.enabled)
						Text(Self._timeFormatter.string(from: entry.date))
							.font(.caption2)
							.foregroundColor(.secondary)
					}
				}
				.padding(.vertical, 2)
			}
		}
		.listStyle(.insetGrouped)
		.ashteScreenBackground()
		.navigationTitle(String.localized("Logs"))
		.navigationBarTitleDisplayMode(.inline)
		.overlay {
			if _logs.entries.isEmpty {
				AshteEmptyState(
					icon: "terminal.fill",
					title: .localized("No Logs"),
					message: .localized("Logs from signing, installing and downloading will appear here.")
				)
			}
		}
		.toolbar {
			ToolbarItemGroup(placement: .topBarTrailing) {
				if !_logs.entries.isEmpty {
					ShareLink(item: _logs.exportText) {
						Image(systemName: "square.and.arrow.up")
					}
					Button {
						_logs.clear()
					} label: {
						Image(systemName: "trash")
					}
				}
			}
		}
	}
}
