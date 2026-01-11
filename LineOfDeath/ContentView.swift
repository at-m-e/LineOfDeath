//
//  ContentView.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import Combine

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
    /// キャンセル確認画面
    case cancelConfirm
    /// サンクユー画面
    case thankYou
    /// Due date gone!表示中
    case dueDateGone
    /// カメラ撮影画面
    case photoCapture
    /// 写真表示画面
    case photoDisplay
}

/// タスクの状態を管理するenum
enum TaskStatus {
    /// 締め切り前（カウントダウン中）
    case active
    /// 締め切り超過（未提出、late submission待ち）
    case overdue
    /// 遅れて提出済み（完了）
    case lateSubmitted
}

/// メインのContentView
/// アプリ全体の状態管理と画面遷移を担当
struct ContentView: View {
    /// 現在のアプリの状態
    @State private var appState: AppState = .home
    /// タスク名
    @State private var taskName: String = ""
    /// Oracleモード用のタスク詳細
    @State private var taskDetail: String = ""
    /// デッドラインの日時（日付・時間・分を含む）
    @State private var deadline: Date = Date()
    /// 現在の時刻（タイマー表示用）
    @State private var currentTime: Date = Date()
    /// タスクの状態
    @State private var taskStatus: TaskStatus = .active
    /// 遅延時間（秒）
    @State private var lateDuration: TimeInterval = 0
    /// メインタイマー（1秒ごとに更新）
    @State private var timer: Timer?
    /// キャンセル理由
    @State private var cancelReason: String = ""
    /// Define Your Fateセットアップシート表示フラグ
    @State private var showSetupSheet: Bool = false
    /// AI Scholastic Oracleセットアップシート表示フラグ
    @State private var showOracleSheet: Bool = false
    /// 撮影した写真
    @State private var capturedImage: UIImage?
    /// 写真ピッカー
    @State private var photoPickerItem: PhotosPickerItem?
    /// Due date gone表示フラグ
    @State private var showDueDateGone: Bool = false
    /// カメラ表示フラグ
    @State private var showCamera: Bool = false
    /// キャンセル前にいたタイマー状態（.timerまたは.oracleTimer）
    @State private var previousTimerState: AppState = .timer
    
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
                        // 初期値を現在時刻の1時間後に設定
                        deadline = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
                        showSetupSheet = true
                    },
                    onOracle: {
                        appState = .oracleSetup
                        showOracleSheet = true
                    }
                )
                .environment(\.colorScheme, .dark)
                
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
                            currentTime = Date()
                            // 開始時にすでに期限を過ぎていた場合はDue date gone!画面から始める
                            if currentTime >= deadline {
                                taskStatus = .overdue
                                appState = .dueDateGone
                            } else {
                                taskStatus = .active
                                appState = .timer
                                startTimer()
                            }
                        },
                        onDismiss: {
                            showSetupSheet = false
                            appState = .home
                        }
                    )
                    .presentationDetents([.fraction(0.67)])
                    .presentationDragIndicator(.visible)
                }
                
            case .timer:
                ActiveTimerView(
                    taskName: taskName,
                    deadline: deadline,
                    currentTime: currentTime,
                    taskStatus: $taskStatus,
                    lateDuration: $lateDuration,
                    onSubmitAssignment: {
                        // 期限が過ぎている場合はDue date gone!画面に遷移
                        if currentTime >= deadline {
                            stopTimer()
                            appState = .dueDateGone
                        } else {
                            stopTimer()
                            appState = .success
                        }
                    },
                    onCancel: {
                        previousTimerState = .timer
                        appState = .cancelConfirm
                    },
                    onLateSubmission: {
                        lateDuration = currentTime.timeIntervalSince(deadline)
                        taskStatus = .lateSubmitted
                    }
                )
                
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
                        taskDetail: $taskDetail,
                        onEstablishDefense: { minutes in
                            showOracleSheet = false
                            // 選択された分数でデッドラインを設定
                            deadline = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
                            currentTime = Date()
                            // 開始時にすでに期限を過ぎていた場合はDue date gone!画面から始める
                            if currentTime >= deadline {
                                taskStatus = .overdue
                                appState = .dueDateGone
                            } else {
                                taskStatus = .active
                                appState = .oracleTimer
                                startTimer()
                            }
                        },
                        onDismiss: {
                            showOracleSheet = false
                            appState = .home
                        }
                    )
                    .presentationDetents([.fraction(0.67)])
                    .presentationDragIndicator(.visible)
                }
                
            case .oracleTimer:
                ActiveTimerView(
                    taskName: taskName,
                    deadline: deadline,
                    currentTime: currentTime,
                    taskStatus: $taskStatus,
                    lateDuration: $lateDuration,
                    onSubmitAssignment: {
                        // 期限が過ぎている場合はDue date gone!画面に遷移
                        if currentTime >= deadline {
                            stopTimer()
                            appState = .dueDateGone
                        } else {
                            stopTimer()
                            appState = .success
                        }
                    },
                    onCancel: {
                        stopTimer()
                        previousTimerState = .oracleTimer
                        appState = .cancelReason
                    },
                    onLateSubmission: {
                        lateDuration = currentTime.timeIntervalSince(deadline)
                        taskStatus = .lateSubmitted
                    }
                )
                
            case .success:
                SuccessView(
                    onDismiss: {
                        resetApp()
                    }
                )
                
            case .failure:
                FailureView(
                    showLateSubmission: taskStatus != .lateSubmitted,
                    lateDuration: lateDuration,
                    onLateSubmission: {
                        appState = .dueDateGone
                    },
                    onReturnHome: {
                        resetApp()
                    }
                )
                
            case .cancelReason:
                CancelReasonView(
                    cancelReason: $cancelReason,
                    onSubmit: {
                        appState = .thankYou
                    },
                    onDismiss: {
                        appState = previousTimerState
                        startTimer()
                    }
                )
                
            case .cancelConfirm:
                CancelConfirmView(
                    onConfirm: {
                        stopTimer()
                        appState = .cancelReason
                    },
                    onDismiss: {
                        appState = previousTimerState
                        startTimer()
                    }
                )
                
            case .thankYou:
                ThankYouView(
                    onQuit: {
                        resetApp()
                    }
                )
                
            case .dueDateGone:
                // Time is Up!表示画面（2秒表示後、3秒カウントダウン、その後裏で写真撮影）
                DueDateGoneView(
                    onComplete: { image in
                        if let image = image {
                            capturedImage = image
                        }
                        lateDuration = currentTime.timeIntervalSince(deadline)
                        taskStatus = .lateSubmitted
                        appState = .failure
                    }
                )
                
            case .photoCapture, .photoDisplay:
                // これらのケースは使用されていませんが、enumに定義されているため空のViewを返す
                EmptyView()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    /// タイマーを開始する
    /// 1秒ごとに現在時刻を更新し、デッドラインを超過したかチェック
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                currentTime = Date()
                
                // デッドラインを超過したかチェック
                if currentTime >= deadline && taskStatus == .active {
                    taskStatus = .overdue
                    // 期限切れの瞬間にTime is Up画面へ遷移
                    stopTimer()
                    appState = .dueDateGone
                }
            }
        }
    }
    
    /// タイマーを停止する
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// アプリの状態をリセットする
    private func resetApp() {
        taskName = ""
        taskDetail = ""
        deadline = Date()
        currentTime = Date()
        taskStatus = .active
        lateDuration = 0
        cancelReason = ""
        showSetupSheet = false
        showOracleSheet = false
        capturedImage = nil
        photoPickerItem = nil
        showDueDateGone = false
        showCamera = false
        stopTimer()
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
            Text("Line of Death")
                .font(.system(size: 48, weight: .bold, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // ボタン群
            VStack(spacing: 20) {
                // Define Your Fateボタン
                Button(action: onDefineYourFate) {
                    Text("Manual Timer")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                
                // AI Scholastic Oracleボタン
                Button(action: onOracle) {
                    Text("AI Scheduler")
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
        GeometryReader { geometry in
            VStack(spacing: 30) {
                // タイトル
                Text("Manual Timer")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // タスク名入力フィールド
                VStack(alignment: .leading, spacing: 15) {
                    Text("Task Name")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    TextField("Enter your enemy", text: $taskName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(8)
                }
                
                // デッドライン日時選択（画面の3/4の高さ）
                VStack(alignment: .leading, spacing: 15) {
                    Text("Deadline")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    DatePicker("", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(Color(hex: "#E00122"))
                        .accentColor(Color(hex: "#E00122"))
                        .frame(height: geometry.size.height * 0.75 - 200)
                }
                
                Spacer()
                
                // タイマー開始ボタン（Task name空欄でも開始可能）
                Button(action: {
                    onEstablishDefense()
                }) {
                    Text("Set DEADLINE")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#003660"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#FFD700"))
                        .cornerRadius(12)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#001A33"))
        }
    }
}

/// AI Scholastic Oracle機能のセットアップ画面
struct OracleSetupView: View {
    /// タスク名のバインディング
    @Binding var taskName: String
    /// タスク詳細のバインディング
    @Binding var taskDetail: String
    /// タイマー開始時のコールバック（分を引数として受け取る）
    let onEstablishDefense: (Int) -> Void
    /// 画面を閉じる時のコールバック
    let onDismiss: () -> Void
    
    @State private var showTimePicker = false
    @State private var selectedMinutes = 30
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                // タイトル
                Text("AI Scheduler")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                if !showTimePicker {
                    // 初期状態: 入力フィールド
                    VStack(spacing: 30) {
                        // タスク名入力フィールド
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Task Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("Enter your enemy", text: $taskName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(15)
                                .background(Color(hex: "#002D54"))
                                .cornerRadius(8)
                        }
                        
                        // タスク詳細入力フィールド
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Task Description")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("A 400 words essay on Economics", text: $taskDetail, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .padding(15)
                                .frame(minHeight: 120)
                                .background(Color(hex: "#002D54"))
                                .cornerRadius(8)
                        }
                    }
                    .transition(.opacity)
                } else {
                    // 時間選択状態
                    VStack(spacing: 30) {
                        Text("You have \(selectedMinutes) minutes to complete \(taskName.isEmpty ? "your task" : taskName).")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // 時間調整UI
                        VStack(spacing: 15) {
                            // 上矢印ボタン
                            Button(action: {
                                selectedMinutes += 1
                            }) {
                                Image(systemName: "arrowtriangle.up.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color(hex: "#002D54"))
                                    .clipShape(Circle())
                            }
                            
                            // 時間表示
                            Text("\(selectedMinutes)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(.white)
                            
                            // 下矢印ボタン
                            Button(action: {
                                if selectedMinutes > 1 {
                                    selectedMinutes -= 1
                                }
                            }) {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color(hex: "#002D54"))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                // ボタン
                Button(action: {
                    if !showTimePicker {
                        // "Ask" タップ時: 入力フィールドをフェードアウト、時間選択をフェードイン
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTimePicker = true
                        }
                    } else {
                        // "Set DEADLINE" タップ時: タイマーを開始
                        onEstablishDefense(selectedMinutes)
                    }
                }) {
                    Text(showTimePicker ? "Set DEADLINE" : "Ask")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#003660"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#FFD700"))
                        .cornerRadius(12)
                }
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#001A33"))
        }
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
    /// タスクの状態（バインディング）
    @Binding var taskStatus: TaskStatus
    /// 遅延時間（秒）（バインディング）
    @Binding var lateDuration: TimeInterval
    /// 課題提出時のコールバック
    let onSubmitAssignment: () -> Void
    /// キャンセル時のコールバック
    let onCancel: () -> Void
    /// 遅延提出時のコールバック
    let onLateSubmission: () -> Void
    
    /// 現在時刻のフォーマッター（HH:mm:ss形式）
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    /// デッドラインのフォーマッター（yyyy/MM/dd HH:mm形式）
    let deadlineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
    
    /// 残り時間または経過時間を計算
    var timeDifference: TimeInterval {
        switch taskStatus {
        case .active:
            // 締め切り前：残り時間
            return deadline.timeIntervalSince(currentTime)
        case .overdue:
            // 締め切り超過：経過時間
            return currentTime.timeIntervalSince(deadline)
        case .lateSubmitted:
            // 提出済み：確定した遅延時間
            return lateDuration
        }
    }
    
    /// 時間差を文字列にフォーマット
    var timeDifferenceString: String {
        let totalSeconds = abs(timeDifference)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        
        if taskStatus == .lateSubmitted {
            return String(format: "%d min %d sec late", minutes, seconds)
        }
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    @State private var fadeOpacity: Double = 1.0
    
    var body: some View {
        ZStack {
            // 背景色（赤いボーダーを削除）
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // キャンセルボタン（2秒長押しで発動）
                HStack {
                    Button(action: {}) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "#002D54"))
                            .clipShape(Circle())
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 2.0)
                            .onChanged { _ in
                                // 長押し開始時にフェードアウトアニメーションを開始
                                withAnimation(.linear(duration: 2.0)) {
                                    fadeOpacity = 0.0
                                }
                            }
                            .onEnded { _ in
                                // 長押し終了時に確認画面へ遷移
                                onCancel()
                            }
                    )
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .opacity(fadeOpacity)
                
                Spacer()
                .opacity(fadeOpacity)
                
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
                        
                        // 残り時間/経過時間/遅延時間
                        VStack(spacing: 8) {
                            Text(taskStatus == .active ? "Rest of Your Life" : (taskStatus == .overdue ? "Overdue" : "Late Submitted!"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(timeDifferenceString)
                                .font(.system(size: 72, weight: .bold, design: .monospaced))
                                .foregroundColor(taskStatus == .active ? .white : Color(hex: "#E00122"))
                        }
                    }
                }
                .opacity(fadeOpacity)
                
                Spacer()
                .opacity(fadeOpacity)
                
                // ボタン群
                VStack(spacing: 15) {
                    // 課題提出ボタンまたは遅延提出ボタン
                    if taskStatus == .overdue {
                        Button(action: onLateSubmission) {
                            Text("Late Submission")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color(hex: "#E00122"))
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: onSubmitAssignment) {
                            Text("Submit")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(taskStatus == .lateSubmitted ? Color.gray : Color(hex: "#003660"))
                                .cornerRadius(12)
                        }
                        .disabled(taskStatus == .lateSubmitted)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .opacity(fadeOpacity)
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
                Text("Well done!")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // ホームに戻るボタン
                Button(action: onDismiss) {
                    Text("Return Home")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#003660"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#FFD200"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

/// 失敗画面（Deadline Exceeded画面）
struct FailureView: View {
    /// Late Submissionボタンを表示するかどうか
    let showLateSubmission: Bool
    /// 遅延時間（秒）
    let lateDuration: TimeInterval
    /// Late Submissionボタンのアクション
    let onLateSubmission: () -> Void
    /// ホームに戻る時のコールバック
    let onReturnHome: () -> Void
    
    /// 遅延時間をフォーマットする
    private func formatLateTime(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 {
            components.append("\(minutes)min")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds)s")
        }
        
        return components.joined(separator: " ")
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("Deadline Exceeded")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#E00122"))
                    .multilineTextAlignment(.center)
                
                // 失敗アイコン
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#E00122"))
                
                Spacer()
                
                // ボタン群
                VStack(spacing: 15) {
                    // Late SubmissionボタンまたはSubmitted状態のボタン
                    if showLateSubmission {
                        Button(action: {
                            onLateSubmission()
                        }) {
                            Text("Late Submission")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color(hex: "#E00122"))
                                .cornerRadius(12)
                        }
                    } else {
                        // Submitted状態のボタン表示
                        Button(action: {}) {
                            Text("Submitted - \(formatLateTime(lateDuration)) late")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(true)
                    }
                    
                    // ホームに戻るボタン
                    Button(action: onReturnHome) {
                        Text("Return Home")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#003660"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color(hex: "#FFD200"))
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
    /// タイマーに戻る時のコールバック
    let onDismiss: () -> Void
    /// テキストフィールドのフォーカス状態
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // 左上の×ボタン
                HStack {
                    Button(action: onDismiss) {
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
                
                // タイトル
                Text("Why?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                // 理由入力フィールド
                TextField("Enter your excuse", text: $cancelReason, axis: .vertical)
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
                    Text("Send")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#E00122"))
                        .cornerRadius(12)
                }
                .disabled(cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

/// キャンセル確認画面
struct CancelConfirmView: View {
    /// 確認時のコールバック
    let onConfirm: () -> Void
    /// キャンセル時のコールバック
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("Are you sure?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // ボタン群
                VStack(spacing: 15) {
                    // Yes...ボタン
                    Button(action: onConfirm) {
                        Text("Yes...")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#E00122"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.gray)
                            .cornerRadius(12)
                    }
                    
                    // Just kiddingボタン
                    Button(action: onDismiss) {
                        Text("Just kidding")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color(hex: "#003660"))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

/// サンクユー画面（Thank you.画面）
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
                
                // Quitボタン
                Button(action: onQuit) {
                    Text("Quit")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 150)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
        }
    }
}

/// カメラ撮影用のUIViewControllerRepresentable
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraDevice = .front // インカメラ
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

/// Due date gone!表示画面
struct DueDateGoneView: View {
    /// カメラ撮影後のコールバック（撮影した画像を渡す、失敗時はnil）
    let onComplete: (UIImage?) -> Void
    
    @State private var showCountdown = false
    @State private var countdownValue = 3
    @StateObject private var cameraManager = BackgroundCameraManager()
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                if showCountdown {
                    Text("\(countdownValue)")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(Color(hex: "#E00122"))
                } else {
                    Text("Time is Up!")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: "#E00122"))
                }
                Spacer()
            }
        }
        .onAppear {
            // 2秒後にカウントダウンを開始
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showCountdown = true
                startCountdown()
            }
        }
    }
    
    private func startCountdown() {
        // カウントダウン（3秒間）
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()
                // カウントダウン終了後、裏で写真を撮影
                cameraManager.capturePhoto { image in
                    onComplete(image)
                }
            }
        }
    }
}

/// 裏で写真を撮影するカメラマネージャー
class BackgroundCameraManager: NSObject, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // フロントカメラを使用
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("Failed to add camera input.")
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        
        // 写真出力を追加
        guard session.canAddOutput(photoOutput) else {
            print("Failed to add photo output.")
            session.commitConfiguration()
            return
        }
        session.addOutput(photoOutput)
        
        session.commitConfiguration()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        
        // セッションを開始（バックグラウンドスレッドで）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if !self.session.isRunning {
                self.session.startRunning()
            }
            
            // セッションが開始されるまで少し待つ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
    
    deinit {
        session.stopRunning()
    }
}

extension BackgroundCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        session.stopRunning()
        
        if let error = error {
            print("Error capturing photo: \(error)")
            DispatchQueue.main.async {
                self.captureCompletion?(nil)
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to convert photo to image.")
            DispatchQueue.main.async {
                self.captureCompletion?(nil)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.captureCompletion?(image)
            self.captureCompletion = nil
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
