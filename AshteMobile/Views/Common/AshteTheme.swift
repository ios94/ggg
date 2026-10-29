//
//  AshteTheme.swift
//  AshteMobile
//
//  "Stock" look: white / system backgrounds, flat rows, system blue accent,
//  light-gray "Get" capsules. Same API names as before, so every screen adopts it.
//

import SwiftUI
import UIKit

// MARK: - Palette
enum AshteTheme {
	static let violet = Color.accentColor
	static let pink   = Color(UIColor.systemPink)
	static let orange = Color(UIColor.systemOrange)
	static let cyan   = Color(UIColor.systemCyan)
	static let mint   = Color(UIColor.systemMint)
	static let sun    = Color(UIColor.systemYellow)
	static let blue   = Color(UIColor.systemBlue)
	
	private static func flat(_ color: Color) -> LinearGradient {
		LinearGradient(colors: [color, color.opacity(0.88)], startPoint: .top, endPoint: .bottom)
	}
	
	static let primary = flat(Color.accentColor)
	static let sunset  = flat(Color(UIColor.systemOrange))
	static let ocean   = flat(Color(UIColor.systemCyan))
	static let fresh   = flat(Color(UIColor.systemMint))
	static let candy   = flat(Color(UIColor.systemPink))
	
	static let rotation: [LinearGradient] = [primary, ocean, sunset, fresh]
	
	static func gradient(at index: Int) -> LinearGradient {
		rotation[((index % rotation.count) + rotation.count) % rotation.count]
	}
}

// MARK: - Color helper
extension Color {
	init(ashteHex value: UInt32, opacity: Double = 1) {
		self.init(
			.sRGB,
			red:   Double((value >> 16) & 0xFF) / 255,
			green: Double((value >> 8) & 0xFF) / 255,
			blue:  Double(value & 0xFF) / 255,
			opacity: opacity
		)
	}
}

// MARK: - Background
struct AshteBackground: View {
	var body: some View {
		Color(UIColor.systemBackground)
			.ignoresSafeArea()
			.allowsHitTesting(false)
	}
}

// MARK: - Card (plain grouped surface, no border or shadow)
struct AshteCardModifier: ViewModifier {
	var cornerRadius: CGFloat = 22
	var tint: Color = AshteTheme.violet
	
	func body(content: Content) -> some View {
		content
			.background(Color(UIColor.secondarySystemGroupedBackground))
			.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
	}
}

extension View {
	func ashteCard(cornerRadius: CGFloat = 22, tint: Color = AshteTheme.violet) -> some View {
		modifier(AshteCardModifier(cornerRadius: cornerRadius, tint: tint))
	}
	
	/// Grouped background for lists / forms.
	func ashteScreenBackground() -> some View {
		self
			.scrollContentBackground(.hidden)
			.background(Color(UIColor.systemGroupedBackground))
	}
}

// MARK: - "Get" button: light-gray capsule with blue text
struct AshteGradientButtonStyle: ButtonStyle {
	var gradient: LinearGradient = AshteTheme.primary
	var shadowColor: Color = AshteTheme.violet
	var horizontalPadding: CGFloat = 20
	var verticalPadding: CGFloat = 7
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.system(size: 17, weight: .semibold))
			.foregroundColor(Color.accentColor)
			.padding(.horizontal, horizontalPadding)
			.padding(.vertical, verticalPadding)
			.frame(minWidth: 70)
			.background(Color(UIColor.systemGray6))
			.clipShape(Capsule())
			.opacity(configuration.isPressed ? 0.55 : 1)
	}
}

// MARK: - Filled blue capsule (main actions)
struct AshteFilledButtonStyle: ButtonStyle {
	var horizontalPadding: CGFloat = 22
	var verticalPadding: CGFloat = 10
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.system(size: 17, weight: .semibold))
			.foregroundColor(.white)
			.padding(.horizontal, horizontalPadding)
			.padding(.vertical, verticalPadding)
			.background(Color.accentColor)
			.clipShape(Capsule())
			.opacity(configuration.isPressed ? 0.7 : 1)
	}
}

// MARK: - Icon badge (flat squircle)
struct AshteIconBadge: View {
	let systemName: String
	var gradient: LinearGradient = AshteTheme.primary
	var size: CGFloat = 32
	
	var body: some View {
		Image(systemName: systemName)
			.font(.system(size: size * 0.46, weight: .semibold))
			.foregroundColor(.white)
			.frame(width: size, height: size)
			.background(gradient)
			.clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
	}
}

// MARK: - Section title ("Recently Updated   202")
struct AshteSectionTitle: View {
	let title: String
	var count: Int? = nil
	var gradient: LinearGradient = AshteTheme.primary
	
	var body: some View {
		HStack(spacing: 10) {
			Text(title)
				.font(.system(size: 24, weight: .bold))
				.foregroundColor(.primary)
			
			Spacer()
			
			if let count {
				Text("\(count)")
					.font(.system(size: 15))
					.foregroundColor(.secondary)
					.padding(.horizontal, 12)
					.padding(.vertical, 5)
					.background(Color(UIColor.systemGray6))
					.clipShape(Capsule())
			}
		}
	}
}

// MARK: - Category chips (gray capsules, selected = blue)
struct AshteChipBar: View {
	let options: [String]
	@Binding var selection: String
	
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 10) {
				ForEach(options, id: \.self) { option in
					Button {
						UIImpactFeedbackGenerator(style: .light).impactOccurred()
						withAnimation(.easeInOut(duration: 0.2)) {
							selection = option
						}
					} label: {
						Text(option)
							.font(.system(size: 17, weight: .medium))
							.foregroundColor(selection == option ? .white : .primary)
							.padding(.horizontal, 18)
							.padding(.vertical, 10)
							.background(selection == option ? Color.accentColor : Color(UIColor.systemGray5))
							.clipShape(Capsule())
					}
					.buttonStyle(.plain)
				}
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 10)
		}
		.overlay(alignment: .top) { Divider() }
		.overlay(alignment: .bottom) { Divider() }
	}
}

// MARK: - Empty state
struct AshteEmptyState: View {
	let icon: String
	let title: String
	let message: String
	var buttonTitle: String? = nil
	var action: (() -> Void)? = nil
	
	var body: some View {
		VStack(spacing: 14) {
			Image(systemName: icon)
				.font(.system(size: 50, weight: .regular))
				.foregroundColor(.secondary)
				.padding(.bottom, 4)
			
			Text(title)
				.font(.system(size: 24, weight: .bold))
				.multilineTextAlignment(.center)
			
			Text(message)
				.font(.system(size: 16))
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 30)
			
			if let buttonTitle, let action {
				Button(action: action) {
					Text(buttonTitle)
				}
				.buttonStyle(AshteFilledButtonStyle(horizontalPadding: 26, verticalPadding: 12))
				.padding(.top, 6)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding()
	}
}
