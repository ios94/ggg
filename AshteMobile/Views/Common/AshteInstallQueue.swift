//
//  AshteInstallQueue.swift
//  AshteMobile
//
//  Several apps can be downloaded + signed at the same time, but iOS (and this app's
//  installer sheet) can only install ONE app at a time. This queue keeps every signed
//  app and presents the install sheet for them one after another, so none is dropped.
//  Always call it from the main thread.
//

import SwiftUI
import CoreData

final class AshteInstallQueue: ObservableObject {
	static let shared = AshteInstallQueue()
	
	/// The app whose install sheet is currently shown.
	@Published var current: AnyApp?
	
	private var pending: [NSManagedObjectID] = []
	private var seen = Set<NSManagedObjectID>()
	
	func contains(_ id: NSManagedObjectID) -> Bool { seen.contains(id) }
	
	func enqueue(_ id: NSManagedObjectID) {
		guard !seen.contains(id) else { return }
		seen.insert(id)
		pending.append(id)
		presentNextIfIdle()
	}
	
	/// Finds the newest signed app that is not queued yet (retries while Core Data saves).
	func enqueueLatestSigned(since: Date, attempt: Int = 0) {
		DispatchQueue.main.async {
			Storage.shared.context.refreshAllObjects()
			let request = NSFetchRequest<Signed>(entityName: "Signed")
			request.predicate = NSPredicate(format: "date >= %@", since as NSDate)
			request.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
			let all = (try? Storage.shared.context.fetch(request)) ?? []
			
			if let item = all.first(where: { !self.seen.contains($0.objectID) }) {
				self.enqueue(item.objectID)
			} else if attempt < 12 {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
					self.enqueueLatestSigned(since: since, attempt: attempt + 1)
				}
			}
		}
	}
	
	/// Called when the sheet was closed (install finished or user dismissed it).
	func currentDidDismiss() {
		current = nil
		// give the dismiss animation time to finish before presenting the next sheet
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
			self.presentNextIfIdle()
		}
	}
	
	private func presentNextIfIdle() {
		guard current == nil, !pending.isEmpty else { return }
		let id = pending.removeFirst()
		Storage.shared.context.refreshAllObjects()
		if let signed = try? Storage.shared.context.existingObject(with: id) as? Signed {
			current = AnyApp(base: signed)
		} else {
			presentNextIfIdle() // object was deleted, skip it
		}
	}
}

// MARK: - One sheet for the whole app
struct AshteInstallQueueSheet: ViewModifier {
	@ObservedObject private var queue = AshteInstallQueue.shared
	
	func body(content: Content) -> some View {
		content
			.sheet(item: Binding(
				get: { queue.current },
				set: { newValue in
					if newValue == nil { queue.currentDidDismiss() }
				}
			)) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.id(app.id)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
			}
			// manual signing (SigningView) still posts this notification
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("AshteMobile.installApp"))) { _ in
				queue.enqueueLatestSigned(since: Date().addingTimeInterval(-10))
			}
	}
}

extension View {
	func ashteInstallQueueSheet() -> some View {
		modifier(AshteInstallQueueSheet())
	}
}
