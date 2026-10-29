//
//  AshteTopActions.swift
//  AshteMobile
//
//  Library and Settings live behind two small buttons at the top of the main screens
//  (grid icon + gear icon), exactly like the stock store layout.
//

import SwiftUI

struct AshteTopActions: ViewModifier {
	var placement: ToolbarItemPlacement = .topBarTrailing
	
	@State private var _isLibraryPresenting = false
	@State private var _isSettingsPresenting = false
	
	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarItemGroup(placement: placement) {
					Button {
						_isLibraryPresenting = true
					} label: {
						Image(systemName: "square.grid.2x2")
					}
					
					Button {
						_isSettingsPresenting = true
					} label: {
						Image(systemName: "gearshape.2")
					}
				}
			}
			.sheet(isPresented: $_isLibraryPresenting) {
				LibraryView()
			}
			.sheet(isPresented: $_isSettingsPresenting) {
				SettingsView()
			}
	}
}

extension View {
	func ashteTopActions(placement: ToolbarItemPlacement = .topBarTrailing) -> some View {
		modifier(AshteTopActions(placement: placement))
	}
}
