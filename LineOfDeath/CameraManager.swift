//
//  CameraManager.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import UIKit

/// カメラマネージャー（画像合成機能を含む）
class CameraManager {
    /// 画像に失敗メッセージと透かし広告を合成する
    /// - Parameter baseImage: ベース画像（nilの場合は黒いダミー画像を生成）
    /// - Returns: 合成された画像
    static func composeImageWithFailureText(baseImage: UIImage?) -> UIImage {
        // ベース画像の準備
        let image: UIImage
        if let baseImage = baseImage {
            image = baseImage
        } else {
            // 黒いダミー画像を生成（1080x1920、縦向き）
            image = UIImage(color: .black, size: CGSize(width: 1080, height: 1920)) ?? UIImage()
        }
        
        let size = image.size
        let scale = image.scale
        
        // グラフィックスコンテキストを作成
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // ベース画像を描画
        image.draw(in: CGRect(origin: .zero, size: size))
        
        // テキストA: メイン失敗メッセージ（画面中央）
        let mainText = "DEADLINE EXCEEDED (BETA VER.)"
        let mainFont = UIFont.systemFont(ofSize: 72, weight: .bold)
        let mainTextColor = UIColor(red: 224/255, green: 1/255, blue: 34/255, alpha: 1.0) // #E00122
        
        // テキストのサイズを計算
        let mainAttributes: [NSAttributedString.Key: Any] = [
            .font: mainFont,
        ]
        let mainTextSize = mainText.size(withAttributes: mainAttributes)
        let mainTextRect = CGRect(
            x: (size.width - mainTextSize.width) / 2,
            y: (size.height - mainTextSize.height) / 2,
            width: mainTextSize.width,
            height: mainTextSize.height
        )
        
        // ドロップシャドウを描画
        context.setShadow(offset: CGSize(width: 4, height: 4), blur: 8, color: UIColor.black.cgColor)
        
        // テキストを描画
        let mainTextAttributes: [NSAttributedString.Key: Any] = [
            .font: mainFont,
            .foregroundColor: mainTextColor,
        ]
        mainText.draw(in: mainTextRect, withAttributes: mainTextAttributes)
        
        // シャドウをリセット
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // テキストB: 透かし広告（画面右下）
        let watermarkText = "LINE OF DEATH"
        let watermarkFont = UIFont.systemFont(ofSize: 32, weight: .medium)
        let watermarkAttributes: [NSAttributedString.Key: Any] = [
            .font: watermarkFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.5), // 半透明
        ]
        let watermarkTextSize = watermarkText.size(withAttributes: watermarkAttributes)
        let padding: CGFloat = 40
        let watermarkRect = CGRect(
            x: size.width - watermarkTextSize.width - padding,
            y: size.height - watermarkTextSize.height - padding,
            width: watermarkTextSize.width,
            height: watermarkTextSize.height
        )
        watermarkText.draw(in: watermarkRect, withAttributes: watermarkAttributes)
        
        // 合成された画像を取得
        guard let composedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }
        
        return composedImage
    }
}

/// UIImage拡張: 色から画像を生成
extension UIImage {
    /// 指定された色とサイズからUIImageを生成
    /// - Parameters:
    ///   - color: 色
    ///   - size: サイズ
    /// - Returns: 生成されたUIImage（失敗時はnil）
    convenience init?(color: UIColor, size: CGSize) {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        guard let cgImage = image.cgImage else {
            return nil
        }
        
        self.init(cgImage: cgImage)
    }
}
