import AppIntents
import Foundation

struct GetRecoveryScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Recovery Score"
    static var description = IntentDescription("Get your current recovery score from Soma Health")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MetricsStore()
        let todayMetrics = store.load(for: Date())
        
        guard let metrics = todayMetrics else {
            return .result(dialog: "I couldn't find your recovery data. Make sure you have recent health data in Soma.")
        }
        
        let score = Int(metrics.recoveryScore.rounded())
        let colorState = ColorState.recovery(score: metrics.recoveryScore)
        
        let dialogText: String
        switch colorState {
        case .green:
            dialogText = "Your recovery score is \(score) - excellent! Your body is well recovered and ready for intense training."
        case .lightGreen:
            dialogText = "Your recovery score is \(score) - good. You're recovered and can handle moderate to high intensity training."
        case .yellow:
            dialogText = "Your recovery score is \(score) - moderate. Consider light to moderate training today."
        case .orange:
            dialogText = "Your recovery score is \(score) - low. Focus on recovery activities and light movement."
        case .red:
            dialogText = "Your recovery score is \(score) - very low. It's a rest day - prioritize sleep and recovery."
        default:
            dialogText = "Your recovery score is \(score). Check the Soma app for detailed guidance."
        }
        
        return .result(dialog: dialogText)
    }
}

struct GetAllScoresIntent: AppIntent {
    static var title: LocalizedStringResource = "Get All Health Scores"
    static var description = IntentDescription("Get all your health scores from Soma")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MetricsStore()
        let todayMetrics = store.load(for: Date())
        
        guard let metrics = todayMetrics else {
            return .result(dialog: "I couldn't find your health data. Make sure you have recent data in Soma.")
        }
        
        let recovery = Int(metrics.recoveryScore.rounded())
        let strain = Int(metrics.strainScore.rounded())
        let sleep = Int(metrics.sleepScore.rounded())
        let stress = Int(metrics.stressScore.rounded())
        
        let dialogText = "Here are your Soma scores: Recovery \(recovery), Sleep \(sleep), Strain \(strain), and Stress \(stress)."
        
        return .result(dialog: dialogText)
    }
}

struct GetTrainingGuidanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Training Guidance"
    static var description = IntentDescription("Get your personalized training recommendation for today")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = MetricsStore()
        let todayMetrics = store.load(for: Date())
        
        guard let metrics = todayMetrics else {
            return .result(dialog: "I couldn't find your data to provide training guidance.")
        }
        
        let recovery = Int(metrics.recoveryScore.rounded())
        
        let recommendation: String
        switch recovery {
        case 67...100:
            recommendation = "Great recovery at \(recovery)! Today is perfect for high intensity training. Your body is well recovered."
        case 50..<67:
            recommendation = "Moderate recovery at \(recovery). Stick to moderate intensity training today."
        case 34..<50:
            recommendation = "Lower recovery at \(recovery). Focus on easy training and active recovery."
        default:
            recommendation = "Low recovery at \(recovery). It's a rest day - prioritize sleep and recovery activities."
        }
        
        return .result(dialog: recommendation)
    }
}