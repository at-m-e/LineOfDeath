//
//  ContentView.swift
//  LineOfDeath
//

import SwiftUI
import UIKit  // 画像処理（UIImage、UIFont、UIColorなど）を使用するため
import AVFoundation  // カメラ機能を使用するため
import GoogleGenerativeAI  // Gemini APIを使用するため

// 煽り文句の書式情報を保持する構造体
struct TauntStyle {
    var text: String = "Default"  // テキスト内容
    var fontSize: CGFloat = 288  // フォントサイズ
    var colorRed: Double = 1.0  // 色（赤成分 0-1）
    var colorGreen: Double = 0.17  // 色（緑成分 0-1）
    var colorBlue: Double = 0.13  // 色（青成分 0-1）
    var positionX: Double = 0.5  // 位置X（0-1、0.5が中央）
    var positionY: Double = 0.5  // 位置Y（0-1、0.5が中央）
    var hasShadow: Bool = false  // シャドーの有無
    var shadowColorRed: Double = 0.0  // シャドー色（赤成分）
    var shadowColorGreen: Double = 0.0  // シャドー色（緑成分）
    var shadowColorBlue: Double = 0.0  // シャドー色（青成分）
    var shadowOffsetX: CGFloat = 4  // シャドーオフセットX
    var shadowOffsetY: CGFloat = 4  // シャドーオフセットY
    var shadowBlur: CGFloat = 8  // シャドーブラー
}

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
    @State private var isAsking = false           // Gemini API呼び出し中のフラグ
    
    // UI状態
    @State private var cancelReason = ""          // キャンセル理由
    @State private var hasLateSubmitted = false   // 遅延提出フラグ
    @State private var lateDuration: TimeInterval = 0  // 遅延時間（秒）
    
    // カメラ関連の状態変数
    @State private var countdown = 3              // カウントダウン値（3,2,1）
    @State private var photoDelegate: PhotoDelegate?  // 写真撮影デリゲート（保持用）
    
    // 煽り文句の書式情報（初期値は"Default"）
    @State private var tauntStyle = TauntStyle()
    
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
                        onSet: { 
                            // 煽り文句を生成してからタイマーを開始
                            generateTauntFromTask()
                            state = .timer
                            startTimer()
                        },
                        onDismiss: { state = .home })
                        
            case .aSet:
                // B2: AIタイマー設定画面 - タスク名、詳細、分数を設定
                ASetView(taskName: $taskName, taskDetail: $taskDetail, 
                        minutes: $selectedMinutes, showPicker: $showTimePicker,
                        isAsking: $isAsking,
                        onAsk: {
                            // Askボタンが押されたらGemini APIを呼び出す
                            askGeminiForMinutes()
                        },
                        onSet: { 
                            // 選択された分数を現在時刻に加算してデッドラインを設定
                            // selectedMinutesは表示用の値（初期値30、失敗時60、成功時は100倍）なので、
                            // 実際の分数に変換する必要がある
                            let actualMinutes: Int
                            if selectedMinutes == 30 {
                                // 初期値（何もしなかった時）: 30分
                                actualMinutes = 30
                            } else if selectedMinutes == 60 {
                                // AIが動いたけど失敗時: 60分（表示値そのまま）
                                actualMinutes = 60
                            } else {
                                // AIが判断した時: 100倍されているので100で割る
                                actualMinutes = selectedMinutes / 100
                            }
                            deadline = Calendar.current.date(byAdding: .minute, value: actualMinutes, to: Date()) ?? Date()
                            // 煽り文句を生成してからタイマーを開始
                            generateTauntFromTask()
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
        isAsking = false  // Gemini API呼び出し中のフラグもリセット
        cancelReason = ""
        hasLateSubmitted = false
        lateDuration = 0
        fTimerStart = nil
        tauntStyle = TauntStyle()  // 煽り文句を"Default"に戻す
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
        
        // テキスト1: 煽り文句（Geminiで生成されたもの、または"Default"）
        let aoriText = tauntStyle.text
        let aoriFont = UIFont.systemFont(ofSize: tauntStyle.fontSize, weight: .bold)
        let aoriColor = UIColor(
            red: tauntStyle.colorRed,
            green: tauntStyle.colorGreen,
            blue: tauntStyle.colorBlue,
            alpha: 1.0
        )
        
        // シャドーを設定する場合はコンテキストに設定
        if tauntStyle.hasShadow {
            let shadowColor = UIColor(
                red: tauntStyle.shadowColorRed,
                green: tauntStyle.shadowColorGreen,
                blue: tauntStyle.shadowColorBlue,
                alpha: 1.0
            ).cgColor
            context.setShadow(
                offset: CGSize(width: tauntStyle.shadowOffsetX, height: tauntStyle.shadowOffsetY),
                blur: tauntStyle.shadowBlur,
                color: shadowColor
            )
        }
        
        let aoriAttributes: [NSAttributedString.Key: Any] = [
            .font: aoriFont,
            .foregroundColor: aoriColor
        ]
        let aoriAttributedString = NSAttributedString(string: aoriText, attributes: aoriAttributes)
        let aoriSize = aoriAttributedString.size()
        
        // 位置を計算（positionX, positionYは0-1の範囲、0.5が中央）
        let aoriRect = CGRect(
            x: size.width * CGFloat(tauntStyle.positionX) - aoriSize.width / 2,
            y: size.height * CGFloat(tauntStyle.positionY) - aoriSize.height / 2,
            width: aoriSize.width,
            height: aoriSize.height
        )
        
        // NSAttributedStringを使って描画
        aoriAttributedString.draw(in: aoriRect)
        
        // シャドーをリセット
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // テキスト2: "LINE of DEATH" - 灰色、半透明、右下、小さい（4倍に拡大: 24 * 4 = 96）
        let sukasiText = "LINE of DEATH"
        let sukasiFont = UIFont.systemFont(ofSize: 96, weight: .medium)
        let sukasiColor = UIColor.gray.withAlphaComponent(0.7)  // 灰色、半透明（alpha 0.7）
        let sukasiAttributes: [NSAttributedString.Key: Any] = [
            .font: sukasiFont,
            .foregroundColor: sukasiColor
        ]
        let sukasiAttributedString = NSAttributedString(string: sukasiText, attributes: sukasiAttributes)
        let sukasiSize = sukasiAttributedString.size()
        let padding: CGFloat = 40  // パディングも少し増やす
        let sukasiRect = CGRect(
            x: size.width - sukasiSize.width - padding,  // 右下
            y: size.height - sukasiSize.height - padding,
            width: sukasiSize.width,
            height: sukasiSize.height
        )
        // NSAttributedStringを使って描画
        sukasiAttributedString.draw(in: sukasiRect)
        
        // 合成された画像を取得
        guard let composedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return baseImage
        }
        
        return composedImage
    }
    
    // Gemini APIを呼び出してタスクの適切な分数を取得する関数
    func askGeminiForMinutes() {
        // 既にリクエスト中の場合は何もしない
        guard !isAsking else { return }
        
        // タスク名と詳細が空の場合は何もしない（ボタンが無効化されているので通常は到達しない）
        guard !taskName.isEmpty || !taskDetail.isEmpty else {
            return
        }
        
        isAsking = true  // リクエスト中フラグを立てる
        
        // Gemini APIキー
        let apiKey = "AIzaSyBo0a3Z_HKiQsEI8P90wWIntxjPHBcDkqo"
        
        // Geminiモデルを初期化
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: apiKey)
        
        // プロンプトを作成（より明確な指示を追加）
        let prompt = """
        Task Name: \(taskName.isEmpty ? "Not specified" : taskName)
        Task Description: \(taskDetail.isEmpty ? "Not specified" : taskDetail)
        
        Estimate the time needed to complete this task in minutes.
        Return ONLY a single integer number between 30 and 180.
        Do NOT include any text, explanation, or units. Only return the number.
        Example: If you estimate 60 minutes, return only: 60
        """
        
        // Gemini APIを呼び出す（非同期）
        Task {
            do {
                print("Gemini API: Sending request with prompt length: \(prompt.count)")
                print("Gemini API: Task Name: '\(taskName)', Task Detail: '\(taskDetail)'")
                let response = try await model.generateContent(prompt)
                print("Gemini API: Received response")
                
                // レスポンスのテキストを取得（response.textを直接使用）
                let responseText = response.text
                
                if let text = responseText {
                    print("Gemini API Response Text: '\(text)'")
                    
                    // テキストをトリム
                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Gemini API Trimmed Text: '\(trimmedText)'")
                    
                    // 数値を抽出（最初に見つかった数値を使用）
                    var foundNumber: Int?
                    
                    // まず、整数として直接解析を試みる
                    if let number = Int(trimmedText) {
                        foundNumber = number
                        print("Gemini API: Direct parse successful: \(number)")
                    } else {
                        // 数字のみを抽出
                        let numbers = trimmedText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        print("Gemini API: Extracted numbers string: '\(numbers)'")
                        if !numbers.isEmpty {
                            foundNumber = Int(numbers)
                            if let num = foundNumber {
                                print("Gemini API: Parsed number: \(num)")
                            } else {
                                print("Gemini API: Failed to convert '\(numbers)' to Int")
                            }
                        } else {
                            print("Gemini API: No numbers found in text")
                        }
                    }
                    
                    if let minutes = foundNumber, minutes > 0 {
                        print("Gemini API: Successfully parsed minutes: \(minutes)")
                        // 30-180分の範囲に制限
                        let clampedMinutes = max(30, min(180, minutes))
                        print("Gemini API: Clamped minutes: \(clampedMinutes)")
                        
                        // メインスレッドでUIを更新（AIが判断した値の100倍を表示）
                        await MainActor.run {
                            selectedMinutes = clampedMinutes * 100  // AIが判断した値の100倍
                            showTimePicker = true
                            isAsking = false
                            print("Gemini API: Set minutes to \(clampedMinutes * 100) (original: \(clampedMinutes))")
                        }
                    } else {
                        print("Gemini API: Failed to parse valid number. foundNumber: \(foundNumber?.description ?? "nil")")
                        // 数値の解析に失敗した場合は60（失敗時の値）を設定
                        await MainActor.run {
                            selectedMinutes = 60  // AIが動いたけど失敗時: 60
                            showTimePicker = true
                            isAsking = false
                        }
                    }
                } else {
                    print("Gemini API: Response text is nil - setting to 60")
                    // レスポンスが空の場合は60（失敗時の値）を設定
                    await MainActor.run {
                        selectedMinutes = 60  // AIが動いたけど失敗時: 60
                        showTimePicker = true
                        isAsking = false
                    }
                }
            } catch {
                // エラーが発生した場合は60（失敗時の値）を設定
                print("Gemini API Error: \(error.localizedDescription)")
                print("Gemini API Error Details: \(error)")
                if let nsError = error as NSError? {
                    print("Gemini API NSError Domain: \(nsError.domain)")
                    print("Gemini API NSError Code: \(nsError.code)")
                    print("Gemini API NSError UserInfo: \(nsError.userInfo)")
                }
                await MainActor.run {
                    selectedMinutes = 60  // AIが動いたけど失敗時: 60
                    showTimePicker = true
                    isAsking = false
                }
            }
        }
    }
    
    // Gemini APIを呼び出してタスクから煽り文句と書式を生成する関数
    func generateTauntFromTask() {
        // Gemini APIキー
        let apiKey = "AIzaSyBo0a3Z_HKiQsEI8P90wWIntxjPHBcDkqo"
        
        // Geminiモデルを初期化
        let model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: apiKey)
        
        // プロンプトを作成（JSON形式で煽り文句と書式情報を要求）
        let prompt = """
        Task Name: \(taskName.isEmpty ? "Not specified" : taskName)
        Task Description: \(taskDetail.isEmpty ? "Not specified" : taskDetail)
        
        This task was not completed on time. Generate a scathing, taunting message (in Japanese) for the user who failed to complete this task.
        Also provide styling information for displaying this text on an image.
        
        Return ONLY a JSON object with the following structure:
        {
            "text": "煽り文句のテキスト（日本語）",
            "fontSize": 数値（推奨範囲: 200-400）,
            "color": {
                "red": 0.0-1.0,
                "green": 0.0-1.0,
                "blue": 0.0-1.0
            },
            "position": {
                "x": 0.0-1.0（0.5が中央）,
                "y": 0.0-1.0（0.5が中央）
            },
            "shadow": {
                "enabled": true/false,
                "color": {
                    "red": 0.0-1.0,
                    "green": 0.0-1.0,
                    "blue": 0.0-1.0
                },
                "offsetX": 数値,
                "offsetY": 数値,
                "blur": 数値
            }
        }
        
        Make the taunt message impactful and scathing. Use bold colors and dramatic effects.
        Return ONLY the JSON, no explanation.
        """
        
        // Gemini APIを呼び出す（非同期）
        Task {
            do {
                print("Gemini Taunt API: Sending request...")
                let response = try await model.generateContent(prompt)
                print("Gemini Taunt API: Received response")
                
                if let text = response.text {
                    print("Gemini Taunt API Response: '\(text)'")
                    
                    // JSONをパース
                    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    // JSON部分のみを抽出（```json```で囲まれている可能性がある）
                    let jsonText = trimmedText
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let jsonData = jsonText.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        
                        // 書式情報を抽出
                        var newStyle = TauntStyle()
                        
                        if let textValue = json["text"] as? String {
                            newStyle.text = textValue
                        }
                        
                        if let fontSize = json["fontSize"] as? Double {
                            newStyle.fontSize = CGFloat(fontSize)
                        }
                        
                        if let color = json["color"] as? [String: Double] {
                            newStyle.colorRed = color["red"] ?? 1.0
                            newStyle.colorGreen = color["green"] ?? 0.17
                            newStyle.colorBlue = color["blue"] ?? 0.13
                        }
                        
                        if let position = json["position"] as? [String: Double] {
                            newStyle.positionX = position["x"] ?? 0.5
                            newStyle.positionY = position["y"] ?? 0.5
                        }
                        
                        if let shadow = json["shadow"] as? [String: Any] {
                            newStyle.hasShadow = shadow["enabled"] as? Bool ?? false
                            
                            if let shadowColor = shadow["color"] as? [String: Double] {
                                newStyle.shadowColorRed = shadowColor["red"] ?? 0.0
                                newStyle.shadowColorGreen = shadowColor["green"] ?? 0.0
                                newStyle.shadowColorBlue = shadowColor["blue"] ?? 0.0
                            }
                            
                            if let offsetX = shadow["offsetX"] as? Double {
                                newStyle.shadowOffsetX = CGFloat(offsetX)
                            }
                            if let offsetY = shadow["offsetY"] as? Double {
                                newStyle.shadowOffsetY = CGFloat(offsetY)
                            }
                            if let blur = shadow["blur"] as? Double {
                                newStyle.shadowBlur = CGFloat(blur)
                            }
                        }
                        
                        // メインスレッドでUIを更新
                        await MainActor.run {
                            tauntStyle = newStyle
                            print("Gemini Taunt API: Updated taunt style - text: '\(newStyle.text)'")
                        }
                    } else {
                        print("Gemini Taunt API: Failed to parse JSON")
                    }
                } else {
                    print("Gemini Taunt API: Response text is nil")
                }
            } catch {
                print("Gemini Taunt API Error: \(error.localizedDescription)")
            }
        }
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
                // ×ボタン（左上）- ホーム画面に戻る
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
                
                // タイトル
                Text("Manual Timer")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
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
                .padding(.bottom, 30)
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
    @Binding var isAsking: Bool          // Gemini API呼び出し中のフラグ
    let onAsk: () -> Void                // Askボタンのアクション
    let onSet: () -> Void                // Set DEADLINEボタンのアクション
    let onDismiss: () -> Void            // キャンセル時のアクション
    
    var body: some View {
            VStack(spacing: 30) {
            // ×ボタン（左上）- ホーム画面に戻る
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
            
                // タイトル
                Text("AI Scheduler")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
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
                    // 初期状態ならGemini APIを呼び出す
                    onAsk()
                    } else {
                    // 時間選択状態ならタイマーを開始
                    onSet() 
                    }
                }) {
                Text(showPicker ? "Set DEADLINE" : (isAsking ? "Asking..." : "Ask"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#003660"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                    .background(Color(hex: "#FFD200"))
                        .cornerRadius(12)
                }
            .disabled(isAsking || (!showPicker && taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && taskDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))  // リクエスト中、またはNameとDescriptionの両方が空欄の場合は無効化
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
