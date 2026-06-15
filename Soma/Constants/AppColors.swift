import SwiftUI

// MARK: - Soma Palette Colors
// Extends the existing Color+Soma extension in ColorState.swift.
// Use these instead of inline Color(hex: "...") throughout the app.

extension Color {
    // Primary palette — vivid "iOS system, dark-vibrant" shades tuned to read
    // premium on pure-black backgrounds. Names are stable; only the hues changed
    // in the V2 redesign so every screen and ColorState mapping upgrades at once.
    static let somaGreen      = Color(hex: "30D158")   // optimal — recovery >80, excellent
    static let somaLightGreen = Color(hex: "A3E635")   // healthy — recovery 65–80, good. Lime/chartreuse
                                                       // so it reads clearly distinct from the deep green above.
    static let somaYellow     = Color(hex: "FFD426")   // watch — mild suppression / debt
    static let somaOrange     = Color(hex: "FF9F0A")   // caution — impaired recovery, elevated RHR
    static let somaRed        = Color(hex: "FF453A")   // needs attention — illness, very low
    static let somaBlue       = Color(hex: "0A84FF")   // sleep, primary accent, navigation
    static let somaPurple     = Color(hex: "BF5AF2")   // HRV accent, notifications
    static let somaDeepPurple = Color(hex: "AF52DE")   // peak activity level
    static let somaGray       = Color(hex: "8E8E93")   // secondary text, disabled, neutral
}
