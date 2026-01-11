//
//  ContentView.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import SwiftUI

enum AppState {
    case home
    case setup
    case timer
    case success
    case failure
    case cancelReason
    case thankYou
}

struct ContentView: View {
    @State private var appState: AppState = .home
    @State private var taskName: String = ""
    @State private var deadline: Date = Date()
    @State private var currentTime: Date = Date()
    @State private var timer: Timer?
    @State private var countdownSeconds: Int = 3
    @State private var showCountdown: Bool = false
    @State private var cancelReason: String = ""
    @State private var showSetupSheet: Bool = false
    @State private var countdownTimer
    : Timer?
    
    let primaryBackground = Color(hex: "#001A33")
    let cardSurface = Color(hex: "#002D54")
    let accentRed = Color(hex: "#E00122")
    let textWhite = Color.white
    let ucsbGold = Color(hex: "#FFD200")
    
    var body: some View {
        ZStack {
            primaryBackground.ignoresSafeArea()
            
            switch appState {
            case .home:
                HomeView(
                    onDefineYourFate: {
                        appState = .setup
                        showSetupSheet = true
                    }
                )
                .environment(\.colorScheme, .dark)
                
            case .setup:
                HomeView(
                    onDefineYourFate: {
                        showSetupSheet = true
                    }
                )
                .sheet(isPresented: $showSetupSheet) {
                    SetupView(
                        taskName: $taskName,
                        deadline: $deadline,
                        onEstablishDefense: {
                            showSetupSheet = false
                            appState = .timer
                            startTimer()
                        },
                        onDismiss: {
                            showSetupSheet = false
                            appState = .home
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
                }
                
            case .timer:
                ActiveTimerView(
                    taskName: taskName,
                    deadline: deadline,
                    currentTime: currentTime,
                    onSubmitAssignment: {
                        stopTimer()
                        appState = .success
                    },
                    onCancel: {
                        stopTimer()
                        appState = .cancelReason
                    }
                )
                
            case .success:
                SuccessView(
                    onDismiss: {
                        resetApp()
                    }
                )
                
            case .failure:
                if showCountdown {
                    CountdownView(seconds: countdownSeconds)
                } else {
                    FailureView(
                        onReturnHome: {
                            resetApp()
                        }
                    )
                }
                
            case .cancelReason:
                CancelReasonView(
                    cancelReason: $cancelReason,
                    onSubmit: {
                        appState = .thankYou
                    }
                )
                
            case .thankYou:
                ThankYouView(
                    onQuit: {
                        resetApp()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                currentTime = Date()
                
                // Check if deadline has passed
                let calendar = Calendar.current
                let currentComponents = calendar.dateComponents([.hour, .minute, .second], from: currentTime)
                let deadlineComponents = calendar.dateComponents([.hour, .minute], from: deadline)
                
                if let currentHour = currentComponents.hour,
                   let currentMinute = currentComponents.minute,
                   let deadlineHour = deadlineComponents.hour,
                   let deadlineMinute = deadlineComponents.minute {
                    
                    let currentTotalMinutes = currentHour * 60 + currentMinute
                    let deadlineTotalMinutes = deadlineHour * 60 + deadlineMinute
                    
                    if currentTotalMinutes >= deadlineTotalMinutes {
                        stopTimer()
                        triggerFailure()
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func triggerFailure() {
        appState = .failure
        showCountdown = true
        countdownSeconds = 3
        startCountdown()
    }
    
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownSeconds = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                countdownSeconds -= 1
                if countdownSeconds <= 0 {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCountdown = false
                    }
                }
            }
        }
    }
    
    private func resetApp() {
        taskName = ""
        deadline = Date()
        currentTime = Date()
        countdownSeconds = 3
        showCountdown = false
        cancelReason = ""
        showSetupSheet = false
        stopTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
        appState = .home
    }
}

struct HomeView: View {
    let onDefineYourFate: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("The Line of Death")
                .font(.system(size: 48, weight: .bold, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            VStack(spacing: 20) {
                Button(action: onDefineYourFate) {
                    Text("Define Your Fate")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                
                Button(action: {}) {
                    Text("AI Scholastic Oracle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54").opacity(0.5))
                        .cornerRadius(12)
                }
                .disabled(true)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#001A33"))
    }
}

struct SetupView: View {
    @Binding var taskName: String
    @Binding var deadline: Date
    let onEstablishDefense: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Define Your Fate")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Task Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("Enter task name", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(15)
                    .background(Color(hex: "#002D54"))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Deadline Time")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                DatePicker("", selection: $deadline, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(Color(hex: "#E00122"))
                    .accentColor(Color(hex: "#E00122"))
            }
            .frame(height: 200)
            
            Spacer()
            
            Button(action: {
                if !taskName.isEmpty {
                    onEstablishDefense()
                }
            }) {
                Text("Establish the Defense")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(taskName.isEmpty ? Color.gray : Color(hex: "#E00122"))
                    .cornerRadius(12)
            }
            .disabled(taskName.isEmpty)
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#001A33"))
    }
}

struct ActiveTimerView: View {
    let taskName: String
    let deadline: Date
    let currentTime: Date
    let onSubmitAssignment: () -> Void
    let onCancel: () -> Void
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    let deadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color(hex: "#E00122"), lineWidth: 2)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 30) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "#002D54"))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                VStack(spacing: 40) {
                    Text(taskName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text("Current Time")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(dateFormatter.string(from: currentTime))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Deadline")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(deadlineFormatter.string(from: deadline))
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#E00122"))
                        }
                    }
                    
                    Text("GPA Erosion")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#E00122"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                Button(action: onSubmitAssignment) {
                    Text("Submit Assignment")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#E00122"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

struct SuccessView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Victory")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD200"))
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#FFD200"))
                
                Text("Assignment Submitted Successfully")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Return Home")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct CountdownView: View {
    let seconds: Int
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if seconds > 0 {
                    Text("\(seconds)")
                        .font(.system(size: 120, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#E00122"))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("0")
                        .font(.system(size: 120, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#E00122"))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: seconds)
        }
    }
}

struct FailureView: View {
    let onReturnHome: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Social Liquidation")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#E00122"))
                    .multilineTextAlignment(.center)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#E00122"))
                
                Text("Deadline Exceeded")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 15) {
                    Button(action: {}) {
                        Text("Late-submitted!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                    }
                    .disabled(true)
                    
                    Button(action: onReturnHome) {
                        Text("Return Home")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color(hex: "#002D54"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct CancelReasonView: View {
    @Binding var cancelReason: String
    let onSubmit: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Why?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                TextField("Enter your reason", text: $cancelReason, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(20)
                    .frame(minHeight: 150)
                    .background(Color(hex: "#002D54"))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: onSubmit) {
                    Text("Submit")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
}

struct ThankYouView: View {
    let onQuit: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Thank you.")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Quit.")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: onQuit) {
                    Text("Return Home")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
