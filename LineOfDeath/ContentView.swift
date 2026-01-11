//
//  ContentView.swift
//  LineOfDeath
//

import SwiftUI
import UIKit  // 画像処理（UIImage、UIFont、UIColorなど）を使用するため
import AVFoundation  // カメラ機能を使用するため

// アプリの画面状態を定義するenum
enum ScreenState {
    case home      // A: ホーム画面
    case mSet      // B1: マニュアルタイマー設定画面
    case aSet      // B2: AIタイマー設定画面
    case timer     // C: タイマー実行画面
    case quit      // Q: キャンセル確認画面
    case why       // R: キャンセル理由入力画面
    case success   // D: 成功画面
    case penalty   // E: ペナルティ画面（カウントダウンと撮影）
    case fail      // F: 失敗画面
}

struct ContentView: View {
    // 現在の画面状態
    @State private var state: ScreenState = .home
    
    // タイマー関連の状態変数
    @State private var currentTime = Date()      // 現在時刻（1秒ごとに更新）
    @State private var deadline = Date()          // デッドライン時刻
    @State private var timer: Timer?              // メインタイマー（残り時間をカウント）
    @State private var fTimerStart: Date?         // Fタイマーの開始時刻（ペナルティ画面で使用）
    
    // セットアップ画面で使用する状態変数
    @State private var taskName = ""              // タスク名
    @State private var taskDetail = ""            // タスク詳細（AIモード用）
    @State private var selectedMinutes = 30       // 選択された分数（AIモード用）
    @State private var showTimePicker = false     // 時間ピッカー表示フラグ（AIモード用）
    
    // UI状態
    @State private var cancelReason = ""          // キャンセル理由
    @State private var hasLateSubmitted = false   // 遅延提出フラグ
    @State private var lateDuration: TimeInterval = 0  // 遅延時間（秒）
    
    // カメラ関連の状態変数
    @State private var countdown = 3              // カウントダウン値（3,2,1）
    @State private var photoDelegate: PhotoDelegate?  // 写真撮影デリゲート（保持用）
    
    var body: some View {
        ZStack {
            // 背景色を設定（深いネイビー）
            Color(hex: "#001A33").ignoresSafeArea()
            
            // 現在の状態に応じて画面を切り替え
            switch state {
            case .home:
                // A: ホーム画面 - タイトルとManual/AIボタンを表示
                HomeView(onManual: { state = .mSet }, onAI: { state = .aSet })
                    .onAppear { reset() }  // 画面表示時に状態をリセット
                    
            case .mSet:
                // B1: マニュアルタイマー設定画面 - タスク名とデッドラインを設定
                MSetView(taskName: $taskName, deadline: $deadline, 
                        onSet: { state = .timer; startTimer() },  // Set DEADLINEボタンでタイマー開始
                        onDismiss: { state = .home })
                        
            case .aSet:
                // B2: AIタイマー設定画面 - タスク名、詳細、分数を設定
                ASetView(taskName: $taskName, taskDetail: $taskDetail, 
                        minutes: $selectedMinutes, showPicker: $showTimePicker,
                        onSet: { 
                            // 選択された分数を現在時刻に加算してデッドラインを設定
                            deadline = Calendar.current.date(byAdding: .minute, value: selectedMinutes, to: Date()) ?? Date()
                            state = .timer
                            startTimer()  // タイマーを開始
                        }, 
                        onDismiss: { state = .home })
                        
            case .timer:
                // C: タイマー実行画面 - 現在時刻、デッドライン、残り時間を表示
                TimerView(current: currentTime, deadline: deadline, 
                         onCancel: { state = .quit },  // ×ボタンでキャンセル確認画面へ
                         onSubmit: { stopTimer(); state = .success })  // Submitボタンで成功画面へ
                    .onAppear { startTimer() }  // 画面表示時にタイマーを開始
                    
            case .quit:
                // Q: キャンセル確認画面 - "Are you sure?"を表示
                QuitView(onYes: { state = .why },  // Yes...ボタンで理由入力画面へ
                        onBack: { state = .timer })  // Just kiddingボタンでタイマー画面に戻る
                    .onAppear { 
                        // タイマーが動いていない場合は開始（タイマーは動き続ける必要がある）
                        if timer == nil { startTimer() } 
                    }
                    
            case .why:
                // R: キャンセル理由入力画面 - "Why?"と入力フィールドを表示
                WhyView(reason: $cancelReason, 
                       onSubmit: { stopTimer(); state = .home },  // Sendボタンでホームへ
                       onBack: { state = .timer })  // ×ボタンでタイマー画面に戻る
                    .onAppear { 
                        // タイマーが動いていない場合は開始（タイマーは動き続ける必要がある）
                        if timer == nil { startTimer() } 
                    }
                    
            case .success:
                // D: 成功画面 - おめでとうメッセージを表示
                SuccessView(onHome: { state = .home })  // Return Homeボタンでホームへ
                
            case .penalty:
                // E: ペナルティ画面 - カウントダウン（3,2,1）を表示
                PenaltyView(count: countdown)
                    .onAppear { 
                        fTimerStart = Date()  // Fタイマーの開始時刻を記録
                        startCountdown()  // カウントダウンを開始
                    }
                    
            case .fail:
                // F: 失敗画面 - デッドライン超過メッセージを表示
                FailView(start: fTimerStart, submitted: hasLateSubmitted, duration: lateDuration,
                         onLate: { 
                             // Late-submissionボタンが押されたら、Fタイマーを停止して遅延時間を計算
                             if !hasLateSubmitted { 
                                 lateDuration = Date().timeIntervalSince(fTimerStart ?? Date())
                                 hasLateSubmitted = true 
                             } 
                         },
                         onHome: { state = .home })  // Return Homeボタンでホームへ
            }
        }
        .preferredColorScheme(.dark)  // ダークモードを強制
    }
    
    // 状態を初期化する関数（ホーム画面表示時に呼ばれる）
    func reset() {
        taskName = ""
        taskDetail = ""
        deadline = Date()
        currentTime = Date()
        selectedMinutes = 30
        showTimePicker = false
        cancelReason = ""
        hasLateSubmitted = false
        lateDuration = 0
        fTimerStart = nil
        stopTimer()  // タイマーを停止
    }
    
    // メインタイマーを開始する関数（1秒ごとに現在時刻を更新し、デッドライン超過をチェック）
    func startTimer() {
        stopTimer()  // 既存のタイマーを停止
        currentTime = Date()  // 現在時刻を更新
        
        // 1秒ごとに実行されるタイマーを作成
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = Date()  // 現在時刻を更新
            
            // デッドラインを超過した場合、かつタイマー/Quit/Why画面にいる場合
            if currentTime >= deadline && (state == .timer || state == .quit || state == .why) {
                stopTimer()  // タイマーを停止
                state = .penalty  // ペナルティ画面へ遷移（DUEイベント）
            }
        }
    }
    
    // メインタイマーを停止する関数
    func stopTimer() {
        timer?.invalidate()  // タイマーを無効化
        timer = nil
    }
    
    // カウントダウンを開始する関数（3,2,1とカウントし、0になったら写真を撮影）
    func startCountdown() {
        countdown = 3  // カウントダウンを3にリセット
        
        // 1秒ごとにカウントダウンを減らすタイマーを作成
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            countdown -= 1  // カウントダウンを1減らす
            
            if countdown <= 0 {
                t.invalidate()  // タイマーを停止
                capturePhoto()  // 写真を撮影
            }
        }
    }
    
    // フロントカメラで写真を撮影する関数
    func capturePhoto() {
        // カメラセッションを作成
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // フロントカメラを取得
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera), 
              session.canAddInput(input) else {
            // カメラの取得に失敗した場合は失敗画面へ遷移
            state = .fail
            return
        }
        
        session.addInput(input)  // カメラ入力をセッションに追加
        
        // 写真出力を作成
        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else { 
            state = .fail
            return 
        }
        session.addOutput(output)  // 写真出力をセッションに追加
        
        // 写真撮影完了時のコールバックを定義
        let delegate = PhotoDelegate { img in
            if let img = img { 
                // テキストを合成してからInstagramストーリーに共有
                let composedImage = composeTextOnImage(baseImage: img)
                shareToInstagramStories(composedImage)  // Instagramストーリーに共有
            }
            session.stopRunning()  // セッションを停止
            photoDelegate = nil  // デリゲートの参照をクリア
            state = .fail  // 失敗画面へ遷移
        }
        
        photoDelegate = delegate  // デリゲートを保持（解放されないように）
        session.startRunning()  // セッションを開始
        
        // 0.5秒後に写真を撮影（セッションの準備が整うまで待つ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }
    
    // 画像にテキストを合成する関数
    func composeTextOnImage(baseImage: UIImage) -> UIImage {
        let size = baseImage.size
        let scale = baseImage.scale
        
        // グラフィックスコンテキストを作成
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return baseImage
        }
        
        // ベース画像を描画
        baseImage.draw(in: CGRect(origin: .zero, size: size))
        
        // テキスト1: "Default" - ピンク色、真ん中、大きい
        let aoriText = "Default"
        let aoriFont = UIFont.systemFont(ofSize: 72, weight: .bold)
        let aoriColor = UIColor.systemPink  // ピンク色
        let aoriAttributes: [NSAttributedString.Key: Any] = [
            .font: aoriFont,
            .foregroundColor: aoriColor
        ]
        let aoriSize = aoriText.size(withAttributes: aoriAttributes)
        let aoriRect = CGRect(
            x: (size.width - aoriSize.width) / 2,  // 真ん中
            y: (size.height - aoriSize.height) / 2,
            width: aoriSize.width,
            height: aoriSize.height
        )
        aoriText.draw(in: aoriRect, withAttributes: aoriAttributes)
        
        // テキスト2: "LINE of DEATH" - 灰色、半透明、右下、小さい
        let sukasiText = "LINE of DEATH"
        let sukasiFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        let sukasiColor = UIColor.gray.withAlphaComponent(0.7)  // 灰色、半透明（alpha 0.7）
        let sukasiAttributes: [NSAttributedString.Key: Any] = [
            .font: sukasiFont,
            .foregroundColor: sukasiColor
        ]
        let sukasiSize = sukasiText.size(withAttributes: sukasiAttributes)
        let padding: CGFloat = 20
        let sukasiRect = CGRect(
            x: size.width - sukasiSize.width - padding,  // 右下
            y: size.height - sukasiSize.height - padding,
            width: sukasiSize.width,
            height: sukasiSize.height
        )
        sukasiText.draw(in: sukasiRect, withAttributes: sukasiAttributes)
        
        // 合成された画像を取得
        guard let composedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return baseImage
        }
        
        return composedImage
    }
    
    // Instagramストーリーに共有する関数
    func shareToInstagramStories(_ image: UIImage) {
        // バンドルIDを取得
        let bundleId = Bundle.main.bundleIdentifier!
        
        // 画像をPNGデータに変換
        guard let imageData = image.pngData() else {
            print("Failed to convert image to PNG")
            return
        }
        
        // ペーストボードに画像データを配置（Instagramストーリー用のキーを使用）
        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)  // 5分間有効
        ]
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        
        // URLスキームでInstagramストーリーを開く
        let urlString = "instagram-stories://share?source_application=\(bundleId)"
        guard let url = URL(string: urlString) else {
            print("Failed to create Instagram URL")
            return
        }
        
        // Instagramアプリを開く
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                print("Failed to open Instagram")
            }
        }
    }
}

// 写真撮影のデリゲートクラス（AVCapturePhotoCaptureDelegateプロトコルを実装）
class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (UIImage?) -> Void  // 撮影完了時のコールバック
    
    init(completion: @escaping (UIImage?) -> Void) { 
        self.completion = completion 
    }
    
    // 写真の処理が完了したときに呼ばれる
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // エラーがなければ画像データを取得してUIImageに変換、エラーがあればnilを返す
        completion(error == nil ? UIImage(data: photo.fileDataRepresentation() ?? Data()) : nil)
    }
}

// A: ホーム画面のView
struct HomeView: View {
    let onManual: () -> Void  // Manualボタンのアクション
    let onAI: () -> Void      // AIボタンのアクション
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // タイトルを表示
            Text("LINE of DEATH")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // ボタンを縦に並べて表示
            VStack(spacing: 20) {
                // Manualボタン - B1画面へ遷移
                Button(action: onManual) { 
                    Text("Manual")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#002D54"))
                        .cornerRadius(12) 
                }
                
                // AIボタン - B2画面へ遷移
                Button(action: onAI) { 
                    Text("AI")
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
    }
}

// B1: マニュアルタイマー設定画面のView
struct MSetView: View {
    @Binding var taskName: String    // タスク名のバインディング
    @Binding var deadline: Date      // デッドラインのバインディング
    let onSet: () -> Void            // Set DEADLINEボタンのアクション
    let onDismiss: () -> Void        // キャンセル時のアクション
    
    var body: some View {
        GeometryReader { g in
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
                
                // デッドライン選択フィールド
                VStack(alignment: .leading, spacing: 15) {
                    Text("Deadline")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // ホイールスタイルのDatePicker
                    DatePicker("", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(Color(hex: "#E00122"))
                        .frame(height: max(200, min(400, g.size.height * 0.75 - 200)))
                }
                
                Spacer()
                
                // Set DEADLINEボタン - タイマー画面へ遷移
                Button(action: onSet) { 
                    Text("Set DEADLINE")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#003660"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color(hex: "#FFD200"))
                        .cornerRadius(12) 
                }
                .padding(.bottom, 80)
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#001A33"))
        }
    }
}

// B2: AIタイマー設定画面のView
struct ASetView: View {
    @Binding var taskName: String        // タスク名のバインディング
    @Binding var taskDetail: String      // タスク詳細のバインディング
    @Binding var minutes: Int            // 選択された分数のバインディング
    @Binding var showPicker: Bool        // 時間ピッカー表示フラグのバインディング
    let onSet: () -> Void                // Set DEADLINEボタンのアクション
    let onDismiss: () -> Void            // キャンセル時のアクション
    
    var body: some View {
        VStack(spacing: 30) {
            // タイトル
            Text("AI Scheduler")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            if !showPicker {
                // 初期状態: タスク名と詳細の入力フィールドを表示
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
            } else {
                // Askボタンを押した後: 分数選択UIを表示
                VStack(spacing: 30) {
                    // 選択された分数を表示するテキスト
                    (Text("You have ") + 
                     Text("\(minutes)").foregroundColor(Color(hex: "#FFD200")) + 
                     Text(" minutes to complete ") + 
                     Text(taskName.isEmpty ? "your task" : taskName) + 
                     Text("."))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    // 分数を調整するボタン（上下矢印）
                    VStack(spacing: 15) {
                        // 増やすボタン
                        Button(action: { minutes += 1 }) { 
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color(hex: "#002D54"))
                                .clipShape(Circle()) 
                        }
                        
                        // 分数を大きく表示
                        Text("\(minutes)")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(Color(hex: "#FFD200"))
                        
                        // 減らすボタン（1分以上でないと減らせない）
                        Button(action: { if minutes > 1 { minutes -= 1 } }) { 
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color(hex: "#002D54"))
                                .clipShape(Circle()) 
                        }
                    }
                }
            }
            
            Spacer()
            
            // Askボタン（初期状態）またはSet DEADLINEボタン（時間選択状態）
            Button(action: { 
                if !showPicker { 
                    // 初期状態なら時間ピッカーを表示
                    withAnimation { showPicker = true } 
                } else { 
                    // 時間選択状態ならタイマーを開始
                    onSet() 
                } 
            }) {
                Text(showPicker ? "Set DEADLINE" : "Ask")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#003660"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color(hex: "#FFD200"))
                    .cornerRadius(12)
            }
            .padding(.bottom, 30)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#001A33"))
    }
}

// C: タイマー実行画面のView
struct TimerView: View {
    let current: Date      // 現在時刻
    let deadline: Date     // デッドライン時刻
    let onCancel: () -> Void   // キャンセル時のアクション（×ボタン長押し）
    let onSubmit: () -> Void   // Submitボタンのアクション
    
    @State private var overlay = 0.0        // オーバーレイの不透明度（×ボタン長押し用）
    @State private var pressTimer: Timer?   // 長押しタイマー
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33").ignoresSafeArea()
            
            VStack(spacing: 30) {
                // ×ボタン（左上）
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
                        // 長押しジェスチャーを検出
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                // ボタンを押し始めたとき
                                if overlay == 0 { 
                                    // 4秒後にキャンセル確認画面へ遷移するタイマーを設定
                                    pressTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in 
                                        if overlay >= 1 { onCancel() } 
                                    }
                                    // 3秒かけて画面を暗転（非線形イージング）
                                    withAnimation(.easeIn(duration: 3)) { overlay = 1 } 
                                }
                            }
                            .onEnded { _ in 
                                // ボタンを離したとき
                                pressTimer?.invalidate()  // タイマーをキャンセル
                                pressTimer = nil
                                // 0.5秒かけて画面を明るく戻す
                                withAnimation(.easeOut(duration: 0.5)) { overlay = 0 } 
                            }
                    )
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // 時刻情報を表示
                VStack(spacing: 40) {
                    VStack(spacing: 20) {
                        // 現在時刻（秒単位）
                        VStack(spacing: 8) {
                            Text("Current Time")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Text(timeString(from: current, format: "HH:mm:ss"))
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        // デッドライン（分単位）
                        VStack(spacing: 8) {
                            Text("Deadline")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Text(timeString(from: deadline, format: "MM/dd HH:mm"))
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#E00122"))
                        }
                        
                        // 残り時間（秒単位、デッドラインの00秒までの時間）
                        VStack(spacing: 8) {
                            Text("Remaining Time")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            Text(formatTime(max(0, Int(deadline.timeIntervalSince(current)))))
                                .font(.system(size: 72, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
                
                // Submitボタン - タイマーを停止して成功画面へ遷移
                Button(action: onSubmit) { 
                    Text("Submit")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(hex: "#003660"))
                        .cornerRadius(12) 
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            
            // 黒いオーバーレイ（×ボタン長押し時に画面を暗転）
            Color.black.opacity(overlay)
                .ignoresSafeArea()
                .allowsHitTesting(false)  // タッチイベントを透過
        }
    }
    
    // 日付を文字列にフォーマットする関数
    func timeString(from date: Date, format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }
    
    // 秒数をHH:mm:ss形式の文字列にフォーマットする関数
    func formatTime(_ total: Int) -> String {
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// Q: キャンセル確認画面のView
struct QuitView: View {
    let onYes: () -> Void      // Yes...ボタンのアクション
    let onBack: () -> Void     // Just kiddingボタンのアクション
    
    var body: some View {
        ZStack {
            // 黒背景
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // "Are you sure?"を表示
                Text("Are you sure?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // ボタンを縦に並べて表示
                VStack(spacing: 15) {
                    // Yes...ボタン - 理由入力画面へ遷移
                    Button(action: onYes) { 
                        Text("Yes...")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(hex: "#E00122"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.gray)
                            .cornerRadius(12) 
                    }
                    
                    // Just kiddingボタン - タイマー画面に戻る（タイマーは動き続ける）
                    Button(action: onBack) { 
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

// R: キャンセル理由入力画面のView
struct WhyView: View {
    @Binding var reason: String    // キャンセル理由のバインディング
    let onSubmit: () -> Void       // Sendボタンのアクション
    let onBack: () -> Void         // ×ボタンのアクション
    
    var body: some View {
        ZStack {
            // 黒背景
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // ×ボタン（左上）
                HStack { 
                    Button(action: onBack) { 
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
                
                // "Why?"を表示
                Text("Why?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                // 理由入力フィールド
                TextField("Enter your excuse", text: $reason, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .padding(20)
                    .frame(minHeight: 150)
                    .background(Color(hex: "#002D54"))
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Sendボタン - 理由が入力されていない場合は無効化
                Button(action: onSubmit) { 
                    Text("Send")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color(hex: "#E00122"))
                        .cornerRadius(12) 
                }
                .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// D: 成功画面のView
struct SuccessView: View {
    let onHome: () -> Void  // Return Homeボタンのアクション
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33").ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // "Victory"を表示
                Text("Victory")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD200"))
                
                // チェックマークアイコン
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#FFD200"))
                
                // "Well done!"を表示
                Text("Well done!")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Return Homeボタン - ホーム画面へ遷移
                Button(action: onHome) { 
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

// E: ペナルティ画面のView（カウントダウン表示）
struct PenaltyView: View {
    let count: Int  // カウントダウン値（3,2,1）
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33").ignoresSafeArea()
            
            VStack { 
                Spacer()
                // カウントダウン値を画面いっぱいに表示
                Text("\(count)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(Color(hex: "#E00122"))
                Spacer() 
            }
        }
    }
}

// F: 失敗画面のView
struct FailView: View {
    let start: Date?               // Fタイマーの開始時刻
    let submitted: Bool            // 遅延提出フラグ
    let duration: TimeInterval     // 遅延時間（秒）
    let onLate: () -> Void         // Late-submissionボタンのアクション
    let onHome: () -> Void         // Return Homeボタンのアクション
    
    var body: some View {
        ZStack {
            Color(hex: "#001A33").ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // "Deadline Exceeded"を表示
                Text("Deadline Exceeded")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color(hex: "#E00122"))
                
                // ×マークアイコン
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(Color(hex: "#E00122"))
                
                Spacer()
                
                // ボタンを縦に並べて表示
                VStack(spacing: 15) {
                    // Late-submissionボタン - 一度押すと不活性になり、Fタイマーを停止して遅延時間を表示
                    Button(action: onLate) { 
                        Text(submitted ? "Late-submission - \(formatLate(duration)) late" : "Late-submission")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(submitted ? Color.gray : Color(hex: "#E00122"))
                            .cornerRadius(12) 
                    }
                    .disabled(submitted)  // 一度押すと無効化
                    
                    // Return Homeボタン - ホーム画面へ遷移
                    Button(action: onHome) { 
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
    
    // 遅延時間を"~h ~min ~sec late"形式の文字列にフォーマットする関数
    func formatLate(_ d: TimeInterval) -> String {
        let s = Int(d)  // 秒数を整数に変換
        let (h, m, sec) = (s / 3600, (s % 3600) / 60, s % 60)  // 時、分、秒に分解
        
        var c: [String] = []  // コンポーネントを格納する配列
        
        // 0でない値のみを追加
        if h > 0 { c.append("\(h)h") }
        if m > 0 { c.append("\(m)min") }
        if sec > 0 || c.isEmpty { c.append("\(sec)sec") }  // 秒が0でも他がなければ追加
        
        return c.joined(separator: " ")  // スペース区切りで結合
    }
}

// Color拡張：16進数文字列からColorを生成する
extension Color {
    init(hex: String) {
        // 16進数以外の文字を除去
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var i: UInt64 = 0
        Scanner(string: h).scanHexInt64(&i)  // 16進数文字列を数値に変換
        
        let (a, r, g, b): (UInt64, UInt64, UInt64, UInt64)
        
        // 文字列の長さに応じて変換方法を変更
        switch h.count {
        case 3:  // RGB (12-bit) 例: "F00"
            (a, r, g, b) = (255, (i >> 8) * 17, (i >> 4 & 0xF) * 17, (i & 0xF) * 17)
        case 6:  // RGB (24-bit) 例: "FF0000"
            (a, r, g, b) = (255, i >> 16, i >> 8 & 0xFF, i & 0xFF)
        case 8:  // ARGB (32-bit) 例: "FFFF0000"
            (a, r, g, b) = (i >> 24, i >> 16 & 0xFF, i >> 8 & 0xFF, i & 0xFF)
        default:  // 不正な形式の場合は透明
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        // RGB値を0-1の範囲に正規化してColorを生成
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
