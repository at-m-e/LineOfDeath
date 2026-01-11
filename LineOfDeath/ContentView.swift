//
//  ContentView.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import SwiftUI
import PhotosUI
import UIKit

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

/// Oracle用のタスクアイテム
struct OracleTaskItem: Identifiable {
    let id = UUID()
    var taskName: String
    var taskDetail: String
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
    /// Oracle用のタスクリスト（最大3つ）
    @State private var oracleTasks: [OracleTaskItem] = [OracleTaskItem(taskName: "", taskDetail: "")]
    /// 撮影した写真
    @State private var capturedImage: UIImage?
    /// 写真ピッカー
    @State private var photoPickerItem: PhotosPickerItem?
    /// Due date gone表示フラグ
    @State private var showDueDateGone: Bool = false
    /// カメラ表示フラグ
    @State private var showCamera: Bool = false
    
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
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
                        stopTimer()
                        appState = .cancelReason
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
                        oracleTasks: $oracleTasks,
                        onEstablishDefense: {
                            showOracleSheet = false
                            // 最初のタスクの名前を使用（空の場合も可）
                            taskName = oracleTasks.first?.taskName ?? ""
                            // 現在時刻から30分後に自動設定
                            deadline = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
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
                    }
                )
                
            case .thankYou:
                ThankYouView(
                    onQuit: {
                        resetApp()
                    }
                )
                
            case .dueDateGone:
                // Due date gone!表示画面（2秒表示後、カメラに遷移）
                DueDateGoneView(onComplete: {
                    appState = .photoCapture
                })
                
            case .photoCapture:
                // カメラ撮影画面
                ZStack {
                    Color(hex: "#001A33")
                        .ignoresSafeArea()
                    
                    ImagePicker(selectedImage: $capturedImage)
                }
                .onChange(of: capturedImage) { newImage in
                    if newImage != nil {
                        appState = .photoDisplay
                    }
                }
                
            case .photoDisplay:
                // 写真表示画面
                ZStack {
                    Color(hex: "#001A33")
                        .ignoresSafeArea()
                    
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // タップでLate-submission画面に遷移
                                lateDuration = currentTime.timeIntervalSince(deadline)
                                taskStatus = .lateSubmitted
                                appState = .failure
                            }
                    } else {
                        VStack {
                            Spacer()
                            Text("No Image")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                }
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
        oracleTasks = [OracleTaskItem(taskName: "", taskDetail: "")]
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
        GeometryReader { geometry in
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
                    Text("Establish the Defense")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#E00122"))
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
    /// Oracle用のタスクリスト（最大3つ）
    @Binding var oracleTasks: [OracleTaskItem]
    /// タイマー開始時のコールバック
    let onEstablishDefense: () -> Void
    /// 画面を閉じる時のコールバック
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // タイトル
            Text("AI Scholastic Oracle")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
                .padding(.bottom, 20)
            
            // スクロール可能なコンテンツ
            ScrollView {
                VStack(spacing: 30) {
                    // タスクリスト
                    ForEach(Array(oracleTasks.enumerated()), id: \.element.id) { index, task in
                        VStack(alignment: .leading, spacing: 15) {
                            // タスク番号
                            Text("Task \(index + 1)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            // タスク名入力フィールド
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Task Name")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                TextField("Task Name, Enter", text: Binding(
                                    get: { task.taskName },
                                    set: { oracleTasks[index].taskName = $0 }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(15)
                                .background(Color(hex: "#002D54"))
                                .cornerRadius(8)
                            }
                            
                            // タスク詳細入力フィールド
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Task Detail")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                TextField("Enter Task Detail", text: Binding(
                                    get: { task.taskDetail },
                                    set: { oracleTasks[index].taskDetail = $0 }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(15)
                                .background(Color(hex: "#002D54"))
                                .cornerRadius(8)
                            }
                            
                            // +ボタン（最後のタスクの下に表示、最大3つまで）
                            if index == oracleTasks.count - 1 && oracleTasks.count < 3 {
                                Button(action: {
                                    oracleTasks.append(OracleTaskItem(taskName: "", taskDetail: ""))
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Circle())
                                        Spacer()
                                    }
                                }
                                .padding(.top, 10)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .padding(.bottom, 100)
            }
            
            // タイマー開始ボタン（画面下部に固定）
            VStack {
                Button(action: {
                    onEstablishDefense()
                }) {
                    Text("Establish the Defense")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#E00122"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .background(Color(hex: "#001A33"))
        }
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
                            .onEnded { _ in
                                onCancel()
                            }
                    )
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
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#E00122"))
                        }
                        
                        // 残り時間/経過時間/遅延時間
                        VStack(spacing: 8) {
                            Text(taskStatus == .active ? "Remaining" : (taskStatus == .overdue ? "Overdue" : "Late Submitted!"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(timeDifferenceString)
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(taskStatus == .active ? .white : Color(hex: "#E00122"))
                        }
                    }
                    
                    // 警告テキスト
                    if taskStatus == .active {
                        Text("GPA Erosion")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#E00122"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
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
                            Text("Submit Assignment")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(taskStatus == .lateSubmitted ? Color.gray : Color(hex: "#E00122"))
                                .cornerRadius(12)
                        }
                        .disabled(taskStatus == .lateSubmitted)
                    }
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

/// 失敗画面（Social Liquidation画面）
struct FailureView: View {
    /// Late Submissionボタンを表示するかどうか
    let showLateSubmission: Bool
    /// Late Submissionボタンのアクション
    let onLateSubmission: () -> Void
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
                    // Late Submissionボタン（まだ提出していない場合のみ表示）
                    if showLateSubmission {
                        Button(action: onLateSubmission) {
                            Text("Late Submission")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(Color(hex: "#E00122"))
                                .cornerRadius(12)
                        }
                    }
                    
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
                
                // Quit.ボタン
                Button(action: onQuit) {
                    Text("Quit.")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
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
    /// カメラ撮影後のコールバック
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33")
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text("Due date gone!")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#E00122"))
                Spacer()
            }
        }
        .onAppear {
            // 2秒後にカメラを起動
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                onComplete()
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
