//
//  InstagramShareHelper.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import UIKit

/// Instagram Stories共有ヘルパー
/// 
/// **重要:** この機能を使用するには、`Info.plist`に以下の設定が必要です:
/// ```
/// <key>LSApplicationQueriesSchemes</key>
/// <array>
///     <string>instagram-stories</string>
/// </array>
/// ```
struct InstagramShareHelper {
    /// Instagram Storiesに画像を共有する（失敗時は標準のシェアシートを表示）
    /// - Parameter image: 共有する画像
    /// - Returns: 共有に成功した場合true、失敗した場合false
    static func shareToInstagramStories(image: UIImage) -> Bool {
        // URLスキームを使用してInstagram Storiesを開く
        guard let url = URL(string: "instagram-stories://share") else {
            // URLスキームが無効な場合は標準のシェアシートを表示
            showShareSheet(image: image)
            return false
        }
        
        // Instagramアプリがインストールされているかチェック
        guard UIApplication.shared.canOpenURL(url) else {
            print("Instagram is not installed, showing share sheet instead")
            // Instagramがインストールされていない場合は標準のシェアシートを表示
            showShareSheet(image: image)
            return false
        }
        
        // 画像をPNG形式に変換
        guard let imageData = image.pngData() else {
            print("Failed to convert image to PNG")
            showShareSheet(image: image)
            return false
        }
        
        // ペーストボードに画像を配置（Instagram Stories用のキーを使用）
        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5) // 5分間有効
        ]
        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)
        
        // URLスキームでInstagram Storiesを開く
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                print("Failed to open Instagram, showing share sheet instead")
                // 開けなかった場合は標準のシェアシートを表示
                DispatchQueue.main.async {
                    showShareSheet(image: image)
                }
            }
        }
        return true
    }
    
    /// 標準のシェアシートを表示する
    /// - Parameter image: 共有する画像
    private static func showShareSheet(image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("Failed to get root view controller")
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        
        // iPad用の設定
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
}
