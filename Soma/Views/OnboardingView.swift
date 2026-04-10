import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage(UserDefaultsKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(UserDefaultsKeys.userFirstName) private var storedFirstName: String = ""
    @AppStorage(UserDefaultsKeys.userDateOfBirth) private var dobTimestamp: Double = 0
    @AppStorage(UserDefaultsKeys.baselineSleepHours) private var sleepGoalHours: Double = 7.0
    @State private var currentPage = 0
    @State private var nameInput: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
    @State private var isRequesting = false
    @State private var showDenied = false

    private let totalPages = 4

    var body: some View {
        ZStack {
            Color(hex: "0A0A0A").ignoresSafeArea()

            if showDenied {
                PermissionDeniedView()
            } else {
                VStack(spacing: 0) {
                    // Page indicator
                    pageIndicator
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    TabView(selection: $currentPage) {
                        welcomePage.tag(0)
                        namePage.tag(1)
                        sleepGoalPage.tag(2)
                        permissionsPage.tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
                }
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? Color.white : Color.white.opacity(0.25))
                    .frame(width: i == currentPage ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4), value: currentPage)
            }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // App mark
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.somaGreen, Color.somaBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 46))
                        .foregroundColor(.white)
                }

                VStack(spacing: 12) {
                    Text("Welcome to Soma")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Your daily health intelligence engine.\nPowered by Apple Watch.")
                        .font(.body)
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(spacing: 10) {
                    featurePill(icon: "heart.fill",         text: "Recovery Score",  color: Color.somaGreen)
                    featurePill(icon: "flame.fill",         text: "Strain Score",    color: Color.somaOrange)
                    featurePill(icon: "moon.zzz.fill",      text: "Sleep Score",     color: Color.somaBlue)
                    featurePill(icon: "brain.head.profile", text: "Stress Score",    color: Color.somaYellow)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            primaryButton("Get Started") {
                withAnimation { currentPage = 1 }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Name Page

    private var namePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.somaGreen)
                    .symbolEffect(.bounce, value: currentPage == 1)

                VStack(spacing: 10) {
                    Text("Tell us about you")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Your name personalises your daily\nnotifications and insights.")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color.white.opacity(0.4))
                            .frame(width: 20)
                        TextField("", text: $nameInput, prompt: Text("Your first name").foregroundColor(Color.white.opacity(0.35)))
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(Color.white.opacity(0.4))
                            .frame(width: 20)
                        DatePicker(
                            "Date of Birth",
                            selection: $dateOfBirth,
                            in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                        Spacer()
                        let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
                        Text("\(age) yrs")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                primaryButton("Continue") {
                    saveProfile()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { currentPage = 2 }
                }
                ghostButton("Skip") {
                    withAnimation { currentPage = 2 }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Sleep Goal Page

    private var sleepGoalPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.somaBlue)
                    .symbolEffect(.bounce, value: currentPage == 2)

                VStack(spacing: 10) {
                    Text("Sleep Goal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("How many hours of sleep do you aim\nfor each night?")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // Big stepper
                VStack(spacing: 8) {
                    HStack(spacing: 28) {
                        Button {
                            if sleepGoalHours > 5.0 {
                                sleepGoalHours = max(5.0, sleepGoalHours - 0.5)
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(sleepGoalHours <= 5.0 ? Color.white.opacity(0.2) : Color.somaBlue)
                        }

                        Text(String(format: "%.1fh", sleepGoalHours))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: sleepGoalHours)
                            .frame(width: 120)

                        Button {
                            if sleepGoalHours < 12.0 {
                                sleepGoalHours = min(12.0, sleepGoalHours + 0.5)
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(sleepGoalHours >= 12.0 ? Color.white.opacity(0.2) : Color.somaBlue)
                        }
                    }

                    Text(sleepGoalLabel)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                        .animation(.easeInOut, value: sleepGoalHours)
                }
                .padding(24)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.somaBlue.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                primaryButton("Continue") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { currentPage = 3 }
                }
                ghostButton("I'll set this later") {
                    withAnimation { currentPage = 3 }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var sleepGoalLabel: String {
        switch sleepGoalHours {
        case ..<6:  return "Below recommended — consider increasing"
        case 6..<7: return "Minimum recommended range"
        case 7..<9: return "Optimal range for most adults"
        default:    return "Extended recovery goal"
        }
    }

    // MARK: - Permissions Page

    private var permissionsPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color.somaGreen)
                    .symbolEffect(.bounce, value: currentPage == 3)

                VStack(spacing: 10) {
                    Text("Health Access")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Soma reads the following data to\ncompute your scores. Everything stays\non your device — no accounts, no cloud.")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    dataRow(icon: "waveform.path.ecg",  label: "HRV & Heart Rate",           desc: "Recovery & Stress scores")
                    dataRow(icon: "bed.double.fill",    label: "Sleep Analysis",              desc: "Sleep score & stage breakdown")
                    dataRow(icon: "flame.fill",         label: "Active Energy & Steps",       desc: "Strain score")
                    dataRow(icon: "lungs.fill",         label: "VO2 Max & Respiratory Rate",  desc: "Fitness & respiratory insights")
                    dataRow(icon: "thermometer.medium", label: "Wrist Temperature",           desc: "Illness arc detection")
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                primaryButton(isRequesting ? "Requesting..." : "Allow Health Access") {
                    requestAuthorization()
                }
                .disabled(isRequesting)
                .overlay {
                    if isRequesting {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                    }
                }

                ghostButton("Back") {
                    withAnimation { currentPage = 2 }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    private func featurePill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
    }

    private func dataRow(icon: String, label: String, desc: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.somaGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color.somaGreen)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.5))
        }
    }

    private func saveProfile() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            storedFirstName = trimmed.components(separatedBy: .whitespaces).first ?? trimmed
        }
        dobTimestamp = dateOfBirth.timeIntervalSince1970
    }

    private func requestAuthorization() {
        isRequesting = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    hasCompletedOnboarding = true
                    isRequesting = false
                }
            } catch {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showDenied = true
                    isRequesting = false
                }
            }
        }
    }
}

// MARK: - Permission Denied

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.somaRed.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "xmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color.somaRed)
            }

            VStack(spacing: 10) {
                Text("Access Denied")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Soma needs access to your health data to calculate scores.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("To enable access:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                VStack(alignment: .leading, spacing: 4) {
                    stepRow("1", "Open the Settings app")
                    stepRow("2", "Tap Privacy & Security → Health")
                    stepRow("3", "Tap Soma and enable all data types")
                }
            }
            .padding(16)
            .background(Color.somaCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 32)
        }
    }

    private func stepRow(_ number: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(number)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.somaGray)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
