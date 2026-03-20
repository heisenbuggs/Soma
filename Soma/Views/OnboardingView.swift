import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userFirstName") private var storedFirstName: String = ""
    @AppStorage("userDateOfBirth") private var dobTimestamp: Double = 0
    @State private var currentPage = 0
    @State private var nameInput: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
    @State private var isRequesting = false
    @State private var showDenied = false

    var body: some View {
        ZStack {
            Color.somaBackground.ignoresSafeArea()

            if showDenied {
                PermissionDeniedView()
            } else {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    namePage.tag(1)
                    permissionsPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
            }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "00C853"), Color(hex: "2979FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
            }

            VStack(spacing: 12) {
                Text("Welcome to Soma")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("Turn your Apple Watch data into daily health insights.")
                    .font(.body)
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                featurePill(icon: "heart.fill", text: "Recovery Score", color: Color(hex: "00C853"))
                featurePill(icon: "flame.fill", text: "Strain Score", color: Color(hex: "FF9100"))
                featurePill(icon: "moon.zzz.fill", text: "Sleep Score", color: Color(hex: "2979FF"))
                featurePill(icon: "brain.head.profile", text: "Stress Score", color: Color(hex: "FFD600"))
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Name Page

    private var namePage: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "00C853"))

            VStack(spacing: 12) {
                Text("Welcome")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Tell us a bit about yourself")
                    .font(.body)
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                TextField("Your name", text: $nameInput)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(Color.somaCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    Text("Date of Birth")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $dateOfBirth,
                        in: ...Calendar.current.date(byAdding: .year, value: -13, to: Date())!,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.somaCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                let age = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
                Text("Age: \(age) years")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    saveProfile()
                    withAnimation { currentPage = 2 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    withAnimation { currentPage = 2 }
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func saveProfile() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            storedFirstName = trimmed.components(separatedBy: .whitespaces).first ?? trimmed
        }
        dobTimestamp = dateOfBirth.timeIntervalSince1970
    }

    // MARK: - Permissions Page

    private var permissionsPage: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "2979FF"))

            VStack(spacing: 10) {
                Text("Health Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Soma reads the following data to compute your scores. Everything stays on your device.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 14) {
                dataRow(icon: "waveform.path.ecg", label: "HRV & Heart Rate", desc: "Used for Recovery & Stress scores")
                dataRow(icon: "bed.double.fill", label: "Sleep Analysis", desc: "Used for Sleep score")
                dataRow(icon: "flame.fill", label: "Active Energy & Steps", desc: "Used for Strain score")
                dataRow(icon: "lungs.fill", label: "VO2 Max & Respiratory Rate", desc: "Used for fitness tracking")
            }
            .padding(.horizontal, 24)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(Color(hex: "00C853"))
                Text("All data stays on your device. No accounts, no cloud.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    requestAuthorization()
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView().tint(.black).scaleEffect(0.8)
                        } else {
                            Text("Allow Health Access")
                                .font(.headline)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRequesting)

                Button {
                    withAnimation { currentPage = 1 }
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "8E8E93"))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
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
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.somaCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func dataRow(icon: String, label: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(hex: "2979FF"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
        }
    }

    private func requestAuthorization() {
        isRequesting = true
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                await MainActor.run {
                    hasCompletedOnboarding = true
                    isRequesting = false
                }
            } catch {
                await MainActor.run {
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
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "FF1744"))

            VStack(spacing: 10) {
                Text("Access Denied")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Soma needs access to your health data to calculate scores.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("To enable access:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("1. Open Settings app\n2. Tap Privacy & Security → Health\n3. Tap Soma\n4. Enable all data types")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .padding(16)
            .background(Color.somaCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
}
