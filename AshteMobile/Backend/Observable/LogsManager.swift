//
//  LogsManager.swift
//  AshteMobile
//
//  Simple in-app log store shown in the Logs screen.
//

import Foundation
import SwiftUI

final class LogsManager: ObservableObject {
	static let shared = LogsManager()
	
	enum Level: String {
		case info, success, warning, error
		
		var icon: String {
			switch self {
			case .info:    return "info.circle.fill"
			case .success: return "checkmark.circle.fill"
			case .warning: return "exclamationmark.triangle.fill"
			case .error:   return "xmark.octagon.fill"
			}
		}
		
		var color: Color {
			switch self {
			case .info:    return AshteTheme.cyan
			case .success: return AshteTheme.mint
			case .warning: return AshteTheme.orange
			case .error:   return AshteTheme.pink
			}
		}
	}
	
	struct Entry: Identifiable {
		let id = UUID()
		let date: Date
		let level: Level
		let message: String
	}
	
	@Published private(set) var entries: [Entry] = []
	private let _maxEntries = 500
	
	private init() {}
	
	/// Safe to call from any thread.
	func log(_ message: String, level: Level = .info) {
		let entry = Entry(date: Date(), level: level, message: message)
		let append = { [weak self] in
			guard let self else { return }
			self.entries.append(entry)
			if self.entries.count > self._maxEntries {
				self.entries.removeFirst(self.entries.count - self._maxEntries)
			}
		}
		if Thread.isMainThread {
			append()
		} else {
			DispatchQueue.main.async(execute: append)
		}
	}
	
	func clear() {
		entries.removeAll()
	}
	
	var exportText: String {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return entries
			.map { "[\(formatter.string(from: $0.date))] [\($0.level.rawValue.uppercased())] \($0.message)" }
			.joined(separator: "\n")
	}
}
