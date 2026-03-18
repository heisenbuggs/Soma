import AppIntents
import Foundation

struct StartCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Daily Check-In"
    static var description = IntentDescription("Start your daily check-in in Soma Health")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & OpensIntent {
        // The app will be opened and can handle the check-in flow
        return .result(opensIntent: OpenCheckInIntent())
    }
}

struct OpenCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Check-In"
    static var description = IntentDescription("Opens the daily check-in screen")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // Post notification that can be observed by the app to open check-in
        NotificationCenter.default.post(name: .openCheckIn, object: nil)
        return .result()
    }
}

struct GetLastCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Last Check-In"
    static var description = IntentDescription("Get information about your last daily check-in")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let checkInStore = CheckInStore()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        guard let lastCheckIn = checkInStore.load(for: yesterday) else {
            return .result(dialog: "You haven't completed a check-in recently. Would you like to start one now?")
        }
        
        var summary: [String] = []
        
        if lastCheckIn.alcoholConsumed {
            let units = lastCheckIn.alcoholUnits
            let amount = units == 1 ? "1-2 drinks" : units == 2 ? "3-4 drinks" : "5+ drinks"
            summary.append("alcohol (\(amount))")
        }
        
        if lastCheckIn.caffeineAfter5PM {
            summary.append("late caffeine")
        }
        
        if lastCheckIn.screenBeforeBed {
            summary.append("screens before bed")
        }
        
        if lastCheckIn.lateMealBeforeBed {
            summary.append("late meal")
        }
        
        if lastCheckIn.lateWorkout {
            summary.append("late workout")
        }
        
        let stressLevel = ["very low", "low", "moderate", "high", "very high"][lastCheckIn.stressLevel - 1]
        summary.append("stress was \(stressLevel)")
        
        var positives: [String] = []
        if lastCheckIn.meditated {
            positives.append("meditated")
        }
        if lastCheckIn.stretched {
            positives.append("stretched")
        }
        if lastCheckIn.coldExposure {
            positives.append("cold exposure")
        }
        
        var dialogText = "Yesterday"
        if !summary.isEmpty {
            dialogText += " you had: " + summary.joined(separator: ", ")
        }
        if !positives.isEmpty {
            dialogText += positives.isEmpty ? " you did: " : ", and you did: "
            dialogText += positives.joined(separator: ", ")
        }
        dialogText += "."
        
        return .result(dialog: dialogText)
    }
}
