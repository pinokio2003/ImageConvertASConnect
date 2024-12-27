//
//  DropView.swift
//  ImageConvertASConnect
//
//  Created by Anatolii Kravchuk on 27.12.2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropView: View {
    @Binding var droppedImage: NSImage?
    @State private var isTargeted = false
    @State private var dragError = false
    @State private var errorMessage: String?
    
    // Supported file types
    private let supportedTypes: [UTType] = [.image, .fileURL]  // Добавляем .fileURL
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: [10]
                    )
                )
                .foregroundColor(strokeColor)
            
            VStack(spacing: 12) {
                if let image = droppedImage {
                    imagePreview(image)
                } else {
                    dropPrompt
                }
                
                if let error = errorMessage {
                    errorView(error)
                }
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        .animation(.easeInOut(duration: 0.2), value: dragError)
        .onDrop(
            of: supportedTypes.map(\.identifier),
            isTargeted: $isTargeted,
            perform: handleDrop
        )
    }
    
    private var strokeColor: Color {
        if dragError {
            return .red
        }
        return isTargeted ? .blue : .gray
    }
    
    private func imagePreview(_ image: NSImage) -> some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 150)
            
            Text("\(Int(image.size.width))×\(Int(image.size.height))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: clearImage) {
                Label("Clear Image", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var dropPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            
            Text("Drop Image Here")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Supports PNG, JPEG, TIFF")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        Text(error)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.1))
            )
    }
    
    private func clearImage() {
        withAnimation {
            droppedImage = nil
            errorMessage = nil
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            showError("No file provided")
            return false
        }
        
        // Изменим приоритет - сначала проверяем возможность загрузки как файл
        if provider.canLoadObject(ofClass: NSImage.self) {
            provider.loadObject(ofClass: NSImage.self) { image, error in
                DispatchQueue.main.async {
                    if let error = error {
                        showError(error.localizedDescription)
                        return
                    }
                    
                    if let image = image as? NSImage {
                        self.droppedImage = image
                        self.errorMessage = nil
                    } else {
                        showError("Failed to load image")
                    }
                }
            }
            return true
        }
        
        // Если не получилось как NSImage, пробуем через URL
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { (urlData, error) in
            DispatchQueue.main.async {
                if let error = error {
                    showError(error.localizedDescription)
                    return
                }
                
                guard let urlData = urlData as? Data,
                      let url = URL(dataRepresentation: urlData, relativeTo: nil),
                      let image = NSImage(contentsOf: url) else {
                    showError("Invalid image data")
                    return
                }
                
                self.droppedImage = image
                self.errorMessage = nil
            }
        }
        
        return true
    }
    
    private func handleDroppedItem(_ item: NSSecureCoding?, typeIdentifier: String) {
        guard let urlData = item as? Data,
              let url = URL(dataRepresentation: urlData, relativeTo: nil),
              let image = NSImage(contentsOf: url) else {
            showError("Invalid image data")
            return
        }
        
        // Validate image
        switch validateImage(image) {
        case .success:
            withAnimation {
                droppedImage = image
                errorMessage = nil
                dragError = false
            }
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ message: String) {
        withAnimation {
            errorMessage = message
            dragError = true
            
            // Reset error state after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    dragError = false
                    errorMessage = nil
                }
            }
        }
    }
}
