//
//  FilesView.swift
//  AshteMobile
//
//  Simple file manager for the app's Documents folder
//  (import, create folders, rename, share, delete).
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers

// MARK: - Model
struct FileItem: Identifiable, Hashable {
	let url: URL
	let isDirectory: Bool
	let size: Int64
	let date: Date?
	
	var id: URL { url }
	var name: String { url.lastPathComponent }
	
	var icon: String {
		if isDirectory { return "folder.fill" }
		switch url.pathExtension.lowercased() {
		case "ipa", "tipa":   return "shippingbox.fill"
		case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
		case "p12":           return "key.fill"
		case "mobileprovision": return "checkmark.seal.fill"
		case "deb", "dylib":  return "puzzlepiece.extension.fill"
		case "png", "jpg", "jpeg", "gif", "webp": return "photo.fill"
		case "plist", "json", "txt", "log": return "doc.text.fill"
		default:              return "doc.fill"
		}
	}
	
	var gradient: LinearGradient {
		if isDirectory { return AshteTheme.sunset }
		switch url.pathExtension.lowercased() {
		case "ipa", "tipa":   return AshteTheme.primary
		case "p12", "mobileprovision": return AshteTheme.fresh
		default:              return AshteTheme.ocean
		}
	}
}

// MARK: - Root
struct FilesView: View {
	private let _root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	
	var body: some View {
		NBNavigationView(.localized("Files")) {
			FilesBrowserView(directory: _root)
		}
	}
}

// MARK: - Folder browser
struct FilesBrowserView: View {
	let directory: URL
	
	@State private var _items: [FileItem] = []
	@State private var _isImporting = false
	@State private var _isNewFolderPresenting = false
	@State private var _newFolderName = ""
	@State private var _renameTarget: FileItem?
	@State private var _renameName = ""
	@State private var _errorMessage: String?
	
	private var _title: String {
		directory.lastPathComponent == "Documents" ? String.localized("Files") : directory.lastPathComponent
	}
	
	var body: some View {
		List {
			ForEach(_items) { item in
				row(for: item)
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button(role: .destructive) {
							delete(item)
						} label: {
							Label(.localized("Delete"), systemImage: "trash")
						}
					}
					.contextMenu {
						Button {
							_renameName = item.name
							_renameTarget = item
						} label: {
							Label(.localized("Rename"), systemImage: "pencil")
						}
						if !item.isDirectory {
							ShareLink(item: item.url) {
								Label(.localized("Share"), systemImage: "square.and.arrow.up")
							}
						}
						Button(role: .destructive) {
							delete(item)
						} label: {
							Label(.localized("Delete"), systemImage: "trash")
						}
					}
			}
		}
		.listStyle(.insetGrouped)
		.ashteScreenBackground()
		.navigationTitle(_title)
		.navigationBarTitleDisplayMode(.inline)
		.overlay {
			if _items.isEmpty {
				AshteEmptyState(
					icon: "folder.badge.plus",
					title: .localized("No Files"),
					message: .localized("Get started by importing your first file."),
					buttonTitle: .localized("Import"),
					action: { _isImporting = true }
				)
			}
		}
		.toolbar {
			ToolbarItemGroup(placement: .topBarTrailing) {
				Button {
					_newFolderName = ""
					_isNewFolderPresenting = true
				} label: {
					Image(systemName: "folder.badge.plus")
				}
				Button {
					_isImporting = true
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.fileImporter(
			isPresented: $_isImporting,
			allowedContentTypes: [.item],
			allowsMultipleSelection: true
		) { result in
			handleImport(result)
		}
		.alert(String.localized("New Folder"), isPresented: $_isNewFolderPresenting) {
			TextField(.localized("Folder name"), text: $_newFolderName)
			Button(.localized("Cancel"), role: .cancel) {}
			Button(.localized("Create")) { createFolder() }
		} message: {
			Text(.localized("Enter a name for the new folder"))
		}
		.alert(
			String.localized("Rename File"),
			isPresented: Binding(
				get: { _renameTarget != nil },
				set: { if !$0 { _renameTarget = nil } }
			)
		) {
			TextField(.localized("File name"), text: $_renameName)
			Button(.localized("Cancel"), role: .cancel) { _renameTarget = nil }
			Button(.localized("Rename")) { rename() }
		} message: {
			Text(.localized("Enter a new name"))
		}
		.alert(
			String.localized("Error"),
			isPresented: Binding(
				get: { _errorMessage != nil },
				set: { if !$0 { _errorMessage = nil } }
			)
		) {
			Button(.localized("OK"), role: .cancel) {}
		} message: {
			Text(_errorMessage ?? "")
		}
		.onAppear { reload() }
		.refreshable { reload() }
	}
	
	// MARK: Row
	@ViewBuilder
	private func row(for item: FileItem) -> some View {
		let content = HStack(spacing: 14) {
			AshteIconBadge(systemName: item.icon, gradient: item.gradient, size: 38)
			
			VStack(alignment: .leading, spacing: 3) {
				Text(item.name)
					.font(.system(size: 16, weight: .medium, design: .rounded))
					.lineLimit(1)
				
				if item.isDirectory {
					Text(.localized("Folder"))
						.font(.caption)
						.foregroundColor(.secondary)
				} else {
					Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
		
		if item.isDirectory {
			NavigationLink(destination: FilesBrowserView(directory: item.url)) {
				content
			}
		} else {
			content
		}
	}
	
	// MARK: Actions
	private func reload() {
		let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
		let urls = (try? FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: keys,
			options: [.skipsHiddenFiles]
		)) ?? []
		
		_items = urls.map { url in
			let values = try? url.resourceValues(forKeys: Set(keys))
			return FileItem(
				url: url,
				isDirectory: values?.isDirectory ?? false,
				size: Int64(values?.fileSize ?? 0),
				date: values?.contentModificationDate
			)
		}
		.sorted {
			if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
			return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
		}
	}
	
	private func handleImport(_ result: Result<[URL], Error>) {
		switch result {
		case .failure(let error):
			_errorMessage = error.localizedDescription
			LogsManager.shared.log("File import error: \(error.localizedDescription)", level: .error)
		case .success(let urls):
			for url in urls {
				let accessed = url.startAccessingSecurityScopedResource()
				defer { if accessed { url.stopAccessingSecurityScopedResource() } }
				
				let destination = uniqueDestination(for: url.lastPathComponent)
				do {
					try FileManager.default.copyItem(at: url, to: destination)
					LogsManager.shared.log("Imported \(destination.lastPathComponent)", level: .success)
				} catch {
					_errorMessage = error.localizedDescription
					LogsManager.shared.log("Failed to import \(url.lastPathComponent): \(error.localizedDescription)", level: .error)
				}
			}
			reload()
		}
	}
	
	private func uniqueDestination(for name: String) -> URL {
		var candidate = directory.appendingPathComponent(name)
		guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
		
		let base = (name as NSString).deletingPathExtension
		let ext = (name as NSString).pathExtension
		var index = 1
		while FileManager.default.fileExists(atPath: candidate.path) {
			let newName = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
			candidate = directory.appendingPathComponent(newName)
			index += 1
		}
		return candidate
	}
	
	private func createFolder() {
		let name = _newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty else { return }
		do {
			try FileManager.default.createDirectory(
				at: directory.appendingPathComponent(name),
				withIntermediateDirectories: false
			)
			reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
	
	private func rename() {
		guard let target = _renameTarget else { return }
		let name = _renameName.trimmingCharacters(in: .whitespacesAndNewlines)
		_renameTarget = nil
		guard !name.isEmpty, name != target.name else { return }
		do {
			try FileManager.default.moveItem(
				at: target.url,
				to: directory.appendingPathComponent(name)
			)
			reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
	
	private func delete(_ item: FileItem) {
		do {
			try FileManager.default.removeItem(at: item.url)
			LogsManager.shared.log("Deleted \(item.name)", level: .info)
			reload()
		} catch {
			_errorMessage = error.localizedDescription
		}
	}
}
