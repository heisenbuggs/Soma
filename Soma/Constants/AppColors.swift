import SwiftUI

// MARK: - Soma Palette Colors
// Extends the existing Color+Soma extension in ColorState.swift.
// Use these instead of inline Color(hex: "...") throughout the app.

extension Color {
    // Primary palette
    static let somaGreen      = Color(hex: "00C853")   // recovery, success, good states
    static let somaLightGreen = Color(hex: "69F0AE")   // light recovery, muted success
    static let somaYellow     = Color(hex: "FFD600")   // warnings, stress, caution
    static let somaOrange     = Color(hex: "FF9100")   // strain, bedtime, moderate warnings
    static let somaRed        = Color(hex: "FF1744")   // danger, illness, very low
    static let somaBlue       = Color(hex: "2979FF")   // sleep, primary accent, navigation
    static let somaPurple     = Color(hex: "9C27B0")   // HRV accent, notifications
    static let somaDeepPurple = Color(hex: "AA00FF")   // peak activity level
    static let somaGray       = Color(hex: "8E8E93")   // secondary text, disabled, neutral
}
