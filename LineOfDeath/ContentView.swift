//
//  ContentView.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import SwiftUI

/// アプリの状態を管理するenum
enum AppState {
    /// ホーム画面
    case home
    /// Define Your Fateのセットアップ画面
    case setup
    /// Define Your Fateのタイマー実行中
    case timer
    /// AI Scholastic Oracleのセットアップ画面
    case oracleSetup
    /// AI Scholastic Oracleのタイマー実行中
    case oracleTimer
    /// 成功画面
    case success
    /// 失敗画面
    case failure
    /// キャンセル理由入力画面
    case cancelReason
    /// サンクユー画面
    case thankYou
}

/// メインのContentView
/// アプリ全体の状態管理と画面遷移を担当
struct ContentView: View {
    /// 現在のアプリの状態
    @State private var appState: AppState = .home
    /// タスク名
    @State private var taskName: String = ""
    /// デッドラインの日時
    @State private var deadline: Date = Date()
    /// 現在の時刻（タイマー表示用）
    @State private var currentTime: Date = Date()
    /// メインタイマー（1秒ごとに更新）
    @State private var timer: Timer?
    /// カウントダウンの秒数（3...2...1...）
    @State private var countdownSeconds: Int = 3
    /// カウントダウン表示フラグ
    @State private var showCountdown: Bool = false
    /// キャンセル理由
    @State private var cancelReason: String = ""
    /// Define Your Fateセットアップシート表示フラグ
    @State private var showSetupSheet: Bool = false
    /// AI Scholastic Oracleセットアップシート表示フラグ
    @State private var showOracleSheet: Bool = false
    /// カウントダウンタイマー
    @State private var countdownTimer: Timer?
    
    /// プライマリ背景色（Deep Navy）
    let primaryBackground = Color(hex: "#001A33")
    /// カード表面色（UCSB Navy）
    let cardSurface = Color(hex: "#002D54")
    /// アクセント色/アラート色（Canvas Red）
    let accentRed = Color(hex: "#E00122")
    /// テキスト色（白）
    let textWhite = Color.white
    /// UCSBゴールド
    let ucsbGold = Color(hex: "#FFD200")
    
    var body: some View {
        ZStack {
            // 背景色を全画面に適用
            primaryBackground.ignoresSafeArea()
            
            // アプリの状態に応じて画面を切り替え
            switch appState {
            case .home:
                HomeView(
                    onDefineYourFate: {
                        appState = .setup
                        showSetupSheet = true
                    },
                    onOracle: {
                        appState = .oracleSetup
                        showOracleSheet = true
                    }
                )
                .environment(\.colorScheme, .dark)
                
            case .oracleSetup:
                HomeView(
                    onDefineYourFate: {
                        showSetupSheet = true
                    },
                    onOracle: {
                        showOracleSheet = true
                    }
                )
                .sheet(isPresented: $showOracleSheet) {
                    OracleSetupView(
                        taskName: $taskName,
                        deadline: $deadline,
                        onEstablishDefense: {
                            showOracleSheet = false
                            appState = .oracleTimer
                            startTimer()
                        },
                        onDismiss: {
                            showOracleSheet = false
                            appState = .home
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
                }
                
            case .oracleTimer:
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
                
            case .setup:
                HomeView(
                    onDefineYourFate: {
                        showSetupSheet = true
                    },
                    onOracle: {
                        showOracleSheet = true
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
    
    /// タイマーを開始する
    /// 1秒ごとに現在時刻を更新し、デッドラインを超過したかチェック
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                // 現在時刻を更新
                currentTime = Date()
                
                // デッドラインを超過したかチェック
                let calendar = Calendar.current
                let currentComponents = calendar.dateComponents([.hour, .minute, .second], from: currentTime)
                let deadlineComponents = calendar.dateComponents([.hour, .minute], from: deadline)
                
                if let currentHour = currentComponents.hour,
                   let currentMinute = currentComponents.minute,
                   let deadlineHour = deadlineComponents.hour,
                   let deadlineMinute = deadlineComponents.minute {
                    
                    // 時刻を分単位に変換して比較
                    let currentTotalMinutes = currentHour * 60 + currentMinute
                    let deadlineTotalMinutes = deadlineHour * 60 + deadlineMinute
                    
                    // デッドラインを超過した場合、失敗状態に移行
                    if currentTotalMinutes >= deadlineTotalMinutes {
                        stopTimer()
                        triggerFailure()
                    }
                }
            }
        }
    }
    
    /// タイマーを停止する
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 失敗状態をトリガーする
    /// カウントダウンを開始して失敗画面に遷移
    private func triggerFailure() {
        appState = .failure
        showCountdown = true
        countdownSeconds = 3
        startCountdown()
    }
    
    /// カウントダウン（3...2...1...）を開始する
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownSeconds = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                countdownSeconds -= 1
                // カウントダウンが0になったらタイマーを停止
                if countdownSeconds <= 0 {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCountdown = false
                    }
                }
            }
        }
    }
    
    /// アプリの状態をリセットする
    private func resetApp() {
        taskName = ""
        deadline = Date()
        currentTime = Date()
        countdownSeconds = 3
        showCountdown = false
        cancelReason = ""
        showSetupSheet = false
        showOracleSheet = false
        stopTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
        appState = .home
    }
}

/// ホーム画面のView
struct HomeView: View {
    /// Define Your Fateボタンのアクション
    let onDefineYourFate: () -> Void
    /// AI Scholastic Oracleボタンのアクション
    let onOracle: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // タイトル
            Text("The Line of Death")
                .font(.system(size: 48, weight: .bold, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // ボタン群
            VStack(spacing: 20) {
                // Define Your Fateボタン
                Button(action: onDefineYourFate) {
                    Text("Define Your Fate")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                
                // AI Scholastic Oracleボタン
                Button(action: onOracle) {
                    Text("AI Scholastic Oracle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#001A33"))
    }
}

/// Define Your Fate機能のセットアップ画面
struct SetupView: View {
    /// タスク名のバインディング
    @Binding var taskName: String
    /// デッドライン時間のバインディング
    @Binding var deadline: Date
    /// タイマー開始時のコールバック
    let onEstablishDefense: () -> Void
    /// 画面を閉じる時のコールバック
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // タイトル
            Text("Define Your Fate")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            // タスク名入力フィールド
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
            
            // デッドライン時間選択
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
            
            // タイマー開始ボタン
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

/// アクティブなタイマー表示画面
/// Define Your FateとAI Scholastic Oracleの両方で使用される共通のタイマー画面
struct ActiveTimerView: View {
    /// タスク名
    let taskName: String
    /// デッドラインの日時
    let deadline: Date
    /// 現在時刻
    let currentTime: Date
    /// 課題提出時のコールバック
    let onSubmitAssignment: () -> Void
    /// キャンセル時のコールバック
    let onCancel: () -> Void
    
    /// 現在時刻のフォーマッター（HH:mm:ss形式）
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    /// デッドラインのフォーマッター（HH:mm形式）
    let deadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            // 背景色と赤いボーダー
            Color(hex: "#001A33")
                .ignoresSafeArea()
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color(hex: "#E00122"), lineWidth: 2)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 30) {
                // キャンセルボタン
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
                
                // メインコンテンツ
                VStack(spacing: 40) {
                    // タスク名
                    Text(taskName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // 時刻表示
                    VStack(spacing: 20) {
                        // 現在時刻
                        VStack(spacing: 8) {
                            Text("Current Time")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(dateFormatter.string(from: currentTime))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        // デッドライン
                        VStack(spacing: 8) {
                            Text("Deadline")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(deadlineFormatter.string(from: deadline))
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#E00122"))
                        }
                    }
                    
                    // 警告テキスト
                    Text("GPA Erosion")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#E00122"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // 課題提出ボタン
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

/// 成功画面（Victory画面）
struct SuccessView: View {
    /// ホームに戻る時のコールバック
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("Victory")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD200"))
                
                // 成功アイコン
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#FFD200"))
                
                // 成功メッセージ
                Text("Assignment Submitted Successfully")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // ホームに戻るボタン
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

/// カウントダウン表示画面（3...2...1...）
struct CountdownView: View {
    /// カウントダウンの秒数
    let seconds: Int
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // カウントダウンの数字を表示
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

/// 失敗画面（Social Liquidation画面）
struct FailureView: View {
    /// ホームに戻る時のコールバック
    let onReturnHome: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("Social Liquidation")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#E00122"))
                    .multilineTextAlignment(.center)
                
                // 失敗アイコン
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#E00122"))
                
                // 失敗メッセージ
                Text("Deadline Exceeded")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // ボタン群
                VStack(spacing: 15) {
                    // 無効化された遅延提出ボタン
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
                    
                    // ホームに戻るボタン
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

/// キャンセル理由入力画面
struct CancelReasonView: View {
    /// キャンセル理由のバインディング
    @Binding var cancelReason: String
    /// 送信時のコールバック
    let onSubmit: () -> Void
    /// テキストフィールドのフォーカス状態
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("Why?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                // 理由入力フィールド
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
                
                // 送信ボタン
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
                // 画面表示時に自動的にテキストフィールドにフォーカス
                isTextFieldFocused = true
            }
        }
    }
}

/// サンクユー画面（Thank you. Quit.画面）
struct ThankYouView: View {
    /// ホームに戻る時のコールバック
    let onQuit: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("Thank you.")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                // サブタイトル
                Text("Quit.")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                // ホームに戻るボタン
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

/// Color拡張機能
/// 16進数文字列からColorを生成する
extension Color {
    /// 16進数文字列からColorを初期化する
    /// - Parameter hex: 16進数カラーコード（例: "#FF0000" または "FF0000"）
    init(hex: String) {
        // 16進数以外の文字を除去
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        
        // 16進数の桁数に応じて変換
        switch hex.count {
        case 3: // RGB (12-bit) 例: "F00"
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit) 例: "FF0000"
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit) 例: "FFFF0000"
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            // 不正な形式の場合は透明な色を返す
            (a, r, g, b) = (1, 1, 1, 0)
        }

        // RGB値を0-1の範囲に正規化してColorを生成
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
