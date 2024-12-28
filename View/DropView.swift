//
//  DropView.swift
//  ImageConvertASConnect
//
//  Created by Anatolii Kravchuk on 27.12.2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropView: View {
    @Binding var droppedImages: [NSImage]
    @State private var isTargeted = false
    @State private var dragError = false
    @State private var errorMessage: String?
    
    private let supportedTypes: [UTType] = [.image, .fileURL]
    
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
                if !droppedImages.isEmpty {
                    imagesPreview
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
    
    private var imagesPreview: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 10) {
                    ForEach(droppedImages.indices, id: \.self) { index in
                        VStack {
                            Image(nsImage: droppedImages[index])
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 150)
                            
                            Text("\(Int(droppedImages[index].size.width))×\(Int(droppedImages[index].size.height))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Button(action: clearImages) {
                Label("Clear All Images", systemImage: "xmark.circle.fill")
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
            
            Text("Drop Images Here")
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
    
    private func clearImages() {
        withAnimation {
            droppedImages.removeAll()
            errorMessage = nil
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let dispatchGroup = DispatchGroup()
        var loadedImages: [NSImage] = []
        
        for provider in providers {
            dispatchGroup.enter()
            
            // Сначала пробуем загрузить как NSImage
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            showError(error.localizedDescription)
                        }
                        dispatchGroup.leave()
                        return
                    }
                    
                    if let image = image as? NSImage {
                        loadedImages.append(image)
                    }
                    dispatchGroup.leave()
                }
            } else {
                // Если не получилось как NSImage, пробуем через URL
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { (urlData, error) in
                    if let error = error {
                        DispatchQueue.main.async {
                            showError(error.localizedDescription)
                        }
                        dispatchGroup.leave()
                        return
                    }
                    
                    if let urlData = urlData as? Data,
                       let url = URL(dataRepresentation: urlData, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        loadedImages.append(image)
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if loadedImages.isEmpty {
                showError("No valid images found")
            } else {
                droppedImages.append(contentsOf: loadedImages)
                errorMessage = nil
                dragError = false
            }
        }
        
        return true
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
