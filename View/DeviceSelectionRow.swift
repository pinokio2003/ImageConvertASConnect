//
//  DeviceSelectionRow.swift
//  ImageConvertASConnect
//
//  Created by Anatolii Kravchuk on 28.12.2024.
//
import SwiftUI

struct DeviceSelectionRow: View {
    let device: String
    @Binding var isSelected: Bool
    let size: CGSize
    
    var body: some View {
        HStack {
            Toggle(isOn: $isSelected) {
                VStack(alignment: .leading) {
                    Text(device)
                        .font(.system(.body))
                    Text("\(Int(size.width))x\(Int(size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
