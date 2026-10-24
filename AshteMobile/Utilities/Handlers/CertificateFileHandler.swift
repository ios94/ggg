//
//  CertificateFileHandler.swift
//  AshteMobile
//
//  Created by samara on 15.04.2025.
//

import Foundation
import OSLog

final class CertificateFileHandler: NSObject {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	
	private let _key: URL
	private let _provision: URL
	private let _keyPassword: String?
	private let _certNickname: String?
	private let _isDefault: Bool
	
	private var _certPair: Certificate?
	
	init(
		key: URL,
		provision: URL,
		password: String? = nil,
		nickname: String? = nil,
		isDefault: Bool = false
	) {
		self._key = key
		self._provision = provision
		self._keyPassword = password
		self._certNickname = nickname
		self._isDefault = isDefault
		
		_certPair = CertificateReader(provision).decoded
		
		super.init()
	}
	
	func copy() async throws {
		guard
			(_certPair != nil)
		else {
			throw CertificateFileHandlerError.certNotValid
		}
		
		let destinationURL = try await _directory()
		
		let keyAccess = _key.startAccessingSecurityScopedResource()
		let provisionAccess = _provision.startAccessingSecurityScopedResource()
		defer {
			if keyAccess { _key.stopAccessingSecurityScopedResource() }
			if provisionAccess { _provision.stopAccessingSecurityScopedResource() }
		}

		try _fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
		try _fileManager.copyItem(at: _key, to: destinationURL.appendingPathComponent(_key.lastPathComponent))
		try _fileManager.copyItem(at: _provision, to: destinationURL.appendingPathComponent(_provision.lastPathComponent))
	}
	
	func addToDatabase() async throws {
		
		let uuid = _uuid
		let password = _keyPassword
		let nickname = _certNickname
		let ppq = _certPair?.PPQCheck ?? false
		let expiration = _certPair?.ExpirationDate ?? Date()
		let isDefault = _isDefault
		
		await MainActor.run {
			Storage.shared.addCertificate(
				uuid: uuid,
				password: password,
				nickname: nickname,
				ppq: ppq,
				expiration: expiration,
				isDefault: isDefault
			) { _ in
				Logger.misc.info("[\(uuid)] Added to database")
			}
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/AshteMobile/Certificates/\(UUID)
		_fileManager.certificates(_uuid)
	}
}

private enum CertificateFileHandlerError: LocalizedError {
	case certNotValid
	
	var errorDescription: String? {
		"The provisioning profile is not valid or could not be read. Please select it again."
	}
}
