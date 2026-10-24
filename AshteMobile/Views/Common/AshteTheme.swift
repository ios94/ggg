//
//  AshteTheme.swift
//  AshteMobile
//
//  Modern design system: "Midnight Glass".
//  Dark-first (adapts to light), deep canvas, glass-like cards, soft glows,
//  refined gradients and rounded typography.
//
//  Drop-in replacement: every name used by the other screens is kept
//  (violet, pink, orange, cyan, mint, sun, primary, sunset, ocean, fresh, candy,
//  AshteBackground, ashteCard, ashteScreenBackground, AshteGradientButtonStyle,
//  AshteIconBadge, AshteSectionTitle, AshteEmptyState), so no other file changes.
//

import SwiftUI
import UIKit

// MARK: - Palette
enum AshteTheme {
	// Brand colours (names kept for compatibility, values modernised)
	static let violet = Color(ashteHex: 0x6D5DFB)   // indigo, main brand
	static let pink   = Color(ashteHex: 0xFF5E8F)
	static let orange = Color(ashteHex: 0xFF9F43)
	static let cyan   = Color(ashteHex: 0x22D3EE)
	static let mint   = Color(ashteHex: 0x34D399)
	static let sun    = Color(ashteHex: 0xF5B942)   // gold
	static let blue   = Color(ashteHex: 0x3D8BFF)
	
	// Adaptive surfaces
	static let canvas = Color(UIColor { trait in
		trait.userInterfaceStyle == .dark
			? UIColor(red: 0.043, green: 0.043, blue: 0.063, alpha: 1)   // #0B0B10
			: UIColor(red: 0.953, green: 0.957, blue: 0.973, alpha: 1)   // #F3F4F8
	})
	static let surface = Color(UIColor { trait in
		trait.userInterfaceStyle == .dark
			? UIColor(red: 0.082, green: 0.082, blue: 0.114, alpha: 1)   // #15151D
			: UIColor.white
	})
	static let surfaceRaised = Color(UIColor { trait in
		trait.userInterfaceStyle == .dark
			? UIColor(red: 0.118, green: 0.118, blue: 0.157, alpha: 1)   // #1E1E28
			: UIColor(red: 0.929, green: 0.933, blue: 0.957, alpha: 1)
	})
	
	// Gradients
	static let primary = LinearGradient(
		colors: [violet, blue],
		startPoint: .topLeading, endPoint: .bottomTrailing
	)
	static let sunset = LinearGradient(
		colors: [pink, orange],
		startPoint: .topLeading, endPoint: .bottomTrailing
	)
	static let ocean = LinearGradient(
		colors: [cyan, blue],
		startPoint: .topLeading, endPoint: .bottomTrailing
	)
	static let fresh = LinearGradient(
		colors: [mint, cyan],
		startPoint: .topLeading, endPoint: .bottomTrailing
	)
	static let candy = LinearGradient(
		colors: [violet, pink, orange],
		startPoint: .topLeading, endPoint: .bottomTrailing
	)
	static let gold = LinearGradient(
		colors: [Color(ashteHex: 0xFFD66B), sun, Color(ashteHex: 0xE59A1F)],
		startPoint: .topLeading, endPoint: .bottomTrailing
	)
	
	/// Gradients used in rotation for rows/badges so lists feel lively.
	static let rotation: [LinearGradient] = [primary, ocean, sunset, fresh]
	
	static func gradient(at index: Int) -> LinearGradient {
		rotation[((index % rotation.count) + rotation.count) % rotation.count]
	}
}

// MARK: - Color helper
extension Color {
	/// 0xRRGGBB initializer (named differently to avoid clashing with `init(hex: String)`).
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

// MARK: - Background (deep canvas + two soft glows)
struct AshteBackground: View {
	@Environment(\.colorScheme) private var scheme
	
	var body: some View {
		let strength: Double = scheme == .dark ? 1 : 0.55
		ZStack {
			AshteTheme.canvas
			
			RadialGradient(
				colors: [AshteTheme.violet.opacity(0.30 * strength), .clear],
				center: .topLeading, startRadius: 0, endRadius: 460
			)
			
			RadialGradient(
				colors: [AshteTheme.cyan.opacity(0.16 * strength), .clear],
				center: .bottomTrailing, startRadius: 0, endRadius: 520
			)
		}
		.ignoresSafeArea()
		.allowsHitTesting(false)
	}
}

// MARK: - Card (glass surface with hairline border)
struct AshteCardModifier: ViewModifier {
	@Environment(\.colorScheme) private var scheme
	var cornerRadius: CGFloat = 22
	var tint: Color = AshteTheme.violet
	
	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		content
			.background(AshteTheme.surface)
			.clipShape(shape)
			.overlay(
				shape.strokeBorder(
					LinearGradient(
						colors: [
							Color.primary.opacity(scheme == .dark ? 0.16 : 0.08),
							Color.primary.opacity(scheme == .dark ? 0.04 : 0.03)
						],
						startPoint: .top, endPoint: .bottom
					),
					lineWidth: 1
				)
			)
			.shadow(color: tint.opacity(scheme == .dark ? 0.10 : 0.12), radius: 16, x: 0, y: 8)
	}
}

/// Frosted-glass surface for floating elements (bars, pills, overlays).
struct AshteGlassModifier: ViewModifier {
	var cornerRadius: CGFloat = 20
	
	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		content
			.background(.ultraThinMaterial, in: shape)
			.overlay(shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
	}
}

extension View {
	func ashteCard(cornerRadius: CGFloat = 22, tint: Color = AshteTheme.violet) -> some View {
		modifier(AshteCardModifier(cornerRadius: cornerRadius, tint: tint))
	}
	
	func ashteGlass(cornerRadius: CGFloat = 20) -> some View {
		modifier(AshteGlassModifier(cornerRadius: cornerRadius))
	}
	
	/// Deep background behind lists / forms / scroll views.
	func ashteScreenBackground() -> some View {
		self
			.scrollContentBackground(.hidden)
			.background(AshteBackground())
	}
}

// MARK: - Gradient button style (pill with glow + inner highlight)
struct AshteGradientButtonStyle: ButtonStyle {
	var gradient: LinearGradient = AshteTheme.primary
	var shadowColor: Color = AshteTheme.violet
	var horizontalPadding: CGFloat = 22
	var verticalPadding: CGFloat = 9
	
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.system(size: 15, weight: .bold, design: .rounded))
			.foregroundColor(.white)
			.padding(.horizontal, horizontalPadding)
			.padding(.vertical, verticalPadding)
			.background(gradient)
			.overlay(
				Capsule().strokeBorder(
					LinearGradient(
						colors: [Color.white.opacity(0.45), Color.white.opacity(0.02)],
						startPoint: .top, endPoint: .bottom
					),
					lineWidth: 1
				)
			)
			.clipShape(Capsule())
			.shadow(color: shadowColor.opacity(configuration.isPressed ? 0.20 : 0.42), radius: configuration.isPressed ? 5 : 12, x: 0, y: configuration.isPressed ? 2 : 6)
			.scaleEffect(configuration.isPressed ? 0.95 : 1)
			.animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
	}
}

// MARK: - Icon badge (squircle, gradient, glossy edge)
struct AshteIconBadge: View {
	let systemName: String
	var gradient: LinearGradient = AshteTheme.primary
	var size: CGFloat = 32
	
	var body: some View {
		let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
		Image(systemName: systemName)
			.font(.system(size: size * 0.46, weight: .semibold))
			.foregroundColor(.white)
			.frame(width: size, height: size)
			.background(gradient)
			.overlay(
				shape.strokeBorder(
					LinearGradient(
						colors: [Color.white.opacity(0.5), Color.white.opacity(0.0)],
						startPoint: .top, endPoint: .bottom
					),
					lineWidth: 1
				)
			)
			.clipShape(shape)
			.shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
	}
}

// MARK: - Section title
struct AshteSectionTitle: View {
	let title: String
	var count: Int? = nil
	var gradient: LinearGradient = AshteTheme.primary
	
	var body: some View {
		HStack(spacing: 10) {
			Circle()
				.fill(gradient)
				.frame(width: 9, height: 9)
			
			Text(title)
				.font(.system(.title3, design: .rounded).weight(.bold))
				.foregroundColor(.primary)
			
			Spacer()
			
			if let count {
				Text("\(count)")
					.font(.system(size: 13, weight: .bold, design: .rounded))
					.foregroundColor(.primary.opacity(0.75))
					.padding(.horizontal, 11)
					.padding(.vertical, 5)
					.background(Color.primary.opacity(0.08))
					.clipShape(Capsule())
			}
		}
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
		VStack(spacing: 16) {
			Image(systemName: icon)
				.font(.system(size: 46, weight: .semibold))
				.foregroundStyle(AshteTheme.candy)
				.frame(width: 112, height: 112)
				.background(
					Circle().fill(AshteTheme.surface)
				)
				.overlay(
					Circle().strokeBorder(
						LinearGradient(
							colors: [AshteTheme.violet.opacity(0.55), AshteTheme.cyan.opacity(0.15)],
							startPoint: .topLeading, endPoint: .bottomTrailing
						),
						lineWidth: 1.5
					)
				)
				.shadow(color: AshteTheme.violet.opacity(0.25), radius: 22, x: 0, y: 10)
			
			Text(title)
				.font(.system(.title2, design: .rounded).weight(.bold))
				.multilineTextAlignment(.center)
			
			Text(message)
				.font(.subheadline)
				.foregroundColor(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 30)
			
			if let buttonTitle, let action {
				Button(action: action) {
					HStack(spacing: 8) {
						Image(systemName: "plus.circle.fill")
						Text(buttonTitle)
					}
				}
				.buttonStyle(AshteGradientButtonStyle(horizontalPadding: 26, verticalPadding: 13))
				.padding(.top, 6)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.padding()
	}
}

// MARK: - Segmented control (glass pill with sliding highlight)
struct AshteSegmentedControl: View {
	let options: [String]
	@Binding var selection: String
	@Namespace private var _ns
	
	var body: some View {
		HStack(spacing: 4) {
			ForEach(options, id: \.self) { option in
				Button {
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
						selection = option
					}
				} label: {
					Text(option)
						.font(.system(size: 14, weight: .semibold, design: .rounded))
						.foregroundColor(selection == option ? .white : Color.primary.opacity(0.65))
						.frame(maxWidth: .infinity)
						.padding(.vertical, 9)
						.background(
							ZStack {
								if selection == option {
									Capsule()
										.fill(AshteTheme.primary)
										.shadow(color: AshteTheme.violet.opacity(0.35), radius: 8, x: 0, y: 4)
										.matchedGeometryEffect(id: "ashteSegment", in: _ns)
								}
							}
						)
				}
				.buttonStyle(.plain)
			}
		}
		.padding(4)
		.background(AshteTheme.surface, in: Capsule())
		.overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
	}
}

// MARK: - Small tinted pill
struct AshtePill: View {
	let text: String
	var tint: Color = AshteTheme.violet
	
	var body: some View {
		Text(text)
			.font(.system(size: 11, weight: .bold, design: .rounded))
			.foregroundColor(tint)
			.padding(.horizontal, 8)
			.padding(.vertical, 3)
			.background(tint.opacity(0.14))
			.clipShape(Capsule())
	}
}
