//
//  AshteAutoSigner.swift
//  AshteMobile
//
//  "download finished -> sign the app that was just imported -> queue its install".
//
//  Fixes for downloading several apps at once:
//  - signing is driven by DownloadManager (not by a SwiftUI view that may no longer exist)
//  - every imported app is "claimed" by exactly one download, never signed twice / swapped
//  - signing runs one app at a time (serial queue)
//  - every signed app goes into AshteInstallQueue, so all of them get installed
//  Call everything from the main thread.
//

import Foundation
import CoreData
import UIKit

enum AshteAutoSignResult {
	case signed(Imported)
	case skipped
	case failed(Error)
}

enum AshteAutoSignError: LocalizedError {
	case importTimeout
	case noCertificate
	
	var errorDescription: String? {
		switch self {
		case .importTimeout:
			return String.localized("The downloaded app could not be found in your library. Please try again.")
		case .noCertificate:
			return String.localized("No certificate found. Please add a certificate in Settings first.")
		}
	}
}

enum AshteAutoSigner {
	private static var _startTimes: [String: Date] = [:]
	private static var _inflight: [String: [(AshteAutoSignResult) -> Void]] = [:]
	private static var _claimed = Set<NSManagedObjectID>()
	private static var _jobs: [(@escaping () -> Void) -> Void] = []
	private static var _busy = false
	
	// MARK: - Public
	
	/// Call this at the moment the user taps "Get".
	static func markDownloadStart(id: String) {
		_onMain { _startTimes[id] = Date() }
	}
	
	/// Called by DownloadManager when the download was imported successfully.
	static func downloadFinished(id: String, appName: String?) {
		_onMain {
			if UserDefaults.standard.integer(forKey: "AshteMobile.installationMethod") == 1 {
				_startTimes.removeValue(forKey: id)
				return
			}
			_start(id: id, appName: appName ?? "")
		}
	}
	
	/// Views may still call this to get a callback (spinner). It never starts a second signing.
	static func signAfterDownload(
		id: String,
		appName: String,
		completion: @escaping (AshteAutoSignResult) -> Void
	) {
		_onMain {
			if _inflight[id] != nil {
				_inflight[id]?.append(completion)
				return
			}
			guard _startTimes[id] != nil else {
				completion(.skipped)
				return
			}
			_inflight[id] = [completion]
			_start(id: id, appName: appName)
		}
	}
	
	/// Same certificate the Signing screen uses (index into certificates sorted by newest).
	static func selectedCertificate() -> CertificatePair? {
		let request = NSFetchRequest<CertificatePair>(entityName: "CertificatePair")
		request.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
		let certificates = (try? Storage.shared.context.fetch(request)) ?? []
		let index = UserDefaults.standard.integer(forKey: "ashtemobile.selectedCert")
		return certificates.indices.contains(index) ? certificates[index] : certificates.first
	}
	
	// MARK: - Private
	
	private static func _onMain(_ block: @escaping () -> Void) {
		if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
	}
	
	private static func _start(id: String, appName: String) {
		// Only the first caller gets the start time, so a download can never be signed twice.
		guard let start = _startTimes.removeValue(forKey: id) else { return }
		if _inflight[id] == nil { _inflight[id] = [] }
		
		_enqueueJob { done in
			_waitForImport(since: start.addingTimeInterval(-1), appName: appName, attempt: 0) { imported in
				guard let imported else {
					_fail(AshteAutoSignError.importTimeout, id: id)
					done()
					return
				}
				
				let options = OptionsManager.shared.options
				let certificate = selectedCertificate()
				
				if certificate == nil && options.signingOption == .default {
					_fail(AshteAutoSignError.noCertificate, id: id)
					done()
					return
				}
				
				let signStart = Date()
				FR.signPackageFile(
					imported,
					using: options,
					icon: nil,
					certificate: certificate
				) { error in
					if let error {
						_fail(error, id: id)
						done()
						return
					}
					
					if options.post_deleteAppAfterSigned {
						Storage.shared.deleteApp(for: imported)
					}
					
					// signing is serial, so the newest un-queued Signed app is this one
					AshteInstallQueue.shared.enqueueLatestSigned(since: signStart.addingTimeInterval(-1))
					_finish(id: id, result: .signed(imported))
					done()
				}
			}
		}
	}
	
	private static func _enqueueJob(_ job: @escaping (@escaping () -> Void) -> Void) {
		_jobs.append(job)
		_runNext()
	}
	
	private static func _runNext() {
		guard !_busy, !_jobs.isEmpty else { return }
		_busy = true
		let job = _jobs.removeFirst()
		job {
			DispatchQueue.main.async {
				_busy = false
				_runNext()
			}
		}
	}
	
	private static func _finish(id: String, result: AshteAutoSignResult) {
		let callbacks = _inflight.removeValue(forKey: id) ?? []
		callbacks.forEach { $0(result) }
	}
	
	private static func _waitForImport(
		since: Date,
		appName: String,
		attempt: Int,
		found: @escaping (Imported?) -> Void
	) {
		let request = NSFetchRequest<Imported>(entityName: "Imported")
		request.predicate = NSPredicate(format: "date >= %@", since as NSDate)
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
		let results = (try? Storage.shared.context.fetch(request)) ?? []
		
		// newest first -> `.last` is the OLDEST app nobody has claimed yet (keeps download order)
		let unclaimed = results.filter { !_claimed.contains($0.objectID) }
		let named = unclaimed.filter {
			let name = $0.name ?? ""
			return !name.isEmpty && (name.localizedCaseInsensitiveContains(appName) || appName.localizedCaseInsensitiveContains(name))
		}
		
		// Fall back to "any unclaimed app" only after a few seconds, never immediately.
		let match = named.last ?? (attempt >= 6 || appName.isEmpty ? unclaimed.last : nil)
		
		if let match {
			_claimed.insert(match.objectID)
			found(match)
			return
		}
		
		// up to ~30 seconds for big IPA files
		guard attempt < 60 else {
			found(nil)
			return
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			_waitForImport(since: since, appName: appName, attempt: attempt + 1, found: found)
		}
	}
	
	private static func _fail(_ error: Error, id: String) {
		DispatchQueue.main.async {
			UINotificationFeedbackGenerator().notificationOccurred(.error)
			_presentAlert(message: error.localizedDescription)
			_finish(id: id, result: .failed(error))
		}
	}
	
	private static func _presentAlert(message: String) {
		guard
			let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
			var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
		else { return }
		
		while let presented = top.presentedViewController {
			top = presented
		}
		
		let alert = UIAlertController(
			title: String.localized("Signing Failed"),
			message: message,
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default))
		top.present(alert, animated: true)
	}
}
