//
//  OracleSetupView.swift
//  LineOfDeath
//
//  Created by Aoto on 2026/01/10.
//

import SwiftUI

/// AI Scholastic Oracle機能のセットアップ画面
/// Define Your Fateのセットアップ画面と同様の機能を持つ
struct OracleSetupView: View {
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
            Text("AI Scholastic Oracle")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            // タスク名入力フィールド
            VStack(alignment: .leading, spacing: 15) {
                Text("Task Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("Task Name, Enter", text: $taskName)
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
