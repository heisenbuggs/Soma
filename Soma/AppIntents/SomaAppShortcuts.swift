import AppIntents

struct SomaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetRecoveryScoreIntent(),
            phrases: [
                "What's my recovery in \(.applicationName)?",
                "Get my recovery score from \(.applicationName)",
                "How recovered am I in \(.applicationName)?",
                "Check my recovery in \(.applicationName)"
            ],
            shortTitle: "Recovery Score",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: GetAllScoresIntent(),
            phrases: [
                "Get all my scores from \(.applicationName)",
                "What are my health scores in \(.applicationName)?",
                "Show me all my metrics in \(.applicationName)",
                "Get my health summary from \(.applicationName)"
            ],
            shortTitle: "All Scores",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        
        AppShortcut(
            intent: GetTrainingGuidanceIntent(),
            phrases: [
                "Should I train today in \(.applicationName)?",
                "What's my training recommendation in \(.applicationName)?",
                "Get training guidance from \(.applicationName)",
                "How hard should I train today in \(.applicationName)?"
            ],
            shortTitle: "Training Guidance",
            systemImageName: "figure.strengthtraining.traditional"
        )
        
        AppShortcut(
            intent: StartCheckInIntent(),
            phrases: [
                "Start my check-in in \(.applicationName)",
                "Do my daily check-in in \(.applicationName)",
                "Log my daily habits in \(.applicationName)",
                "Start check-in with \(.applicationName)"
            ],
            shortTitle: "Daily Check-In",
            systemImageName: "checkmark.circle.fill"
        )
        
        AppShortcut(
            intent: GetLastCheckInIntent(),
            phrases: [
                "What was my last check-in in \(.applicationName)?",
                "Get my yesterday's check-in from \(.applicationName)",
                "What did I log yesterday in \(.applicationName)?"
            ],
            shortTitle: "Last Check-In",
            systemImageName: "clock.fill"
        )
    }
}