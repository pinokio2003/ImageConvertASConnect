//
//  ContentView.swift
//  ImageConvertASConnect
//
//  Created by Anatolii Kravchuk on 27.12.2024.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedDevices: [String: Bool] = [
        "iPhone 6.9\" (1290x2796)": false,
        "iPhone 6.5\" (1284x2778)": false,
        "iPad 13\" (2064x2752)": false,
        "iPad 12.9\" (2048x2732)": false
    ]
    
    @State private var selectedOrientation: Orientation = .auto
    @State private var droppedImages: [NSImage] = []
    @State private var showAlert = false
    @State private var alertItem: AlertItem?
    
    // Progress states
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var totalCount = 0
    
    private var isConvertButtonEnabled: Bool {
        !droppedImages.isEmpty && selectedDevices.contains { $0.value } && !isProcessing
    }
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            imageDropArea
            deviceSelectionArea
            orientationSelector
            previewArea
            convertButton
        }
        .padding()
        .frame(minWidth: 600, minHeight: 700)
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title),
                  message: Text(item.message),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    private var headerView: some View {
        Text("App Store Screenshot Converter")
            .font(.system(size: 24, weight: .bold))
            .padding(.top)
    }
    
    private var imageDropArea: some View {
        VStack {
            DropView(droppedImages: $droppedImages)
                .frame(maxWidth: .infinity, maxHeight: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            
            if let image = droppedImages.first {
                Text("Original Size: \(Int(image.size.width))x\(Int(image.size.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var deviceSelectionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Devices")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let sortedDevices = selectedDevices.keys.sorted()
                    ForEach(sortedDevices, id: \.self) { device in
                        DeviceSelectionRow(
                            device: device,
                            isSelected: Binding(
                                get: { selectedDevices[device] ?? false },
                                set: { selectedDevices[device] = $0 }
                            ),
                            size: resolutions[device] ?? .zero
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var orientationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Orientation")
                .font(.headline)
            
            Picker("", selection: $selectedOrientation) {
                ForEach(Orientation.allCases) { orientation in
                    Text(orientation.description).tag(orientation)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal)
    }
    
    private var previewArea: some View {
        Group {
            if !droppedImages.isEmpty && isProcessing {
                VStack {
                    ProgressView("Processing \(processedCount)/\(totalCount)")
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("Please wait...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
    
    private var convertButton: some View {
        Button(action: processImages) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                }
                Text(isProcessing ? "Converting..." : "Convert Images")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isConvertButtonEnabled ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!isConvertButtonEnabled)
        .padding(.horizontal)
    }
    
    private func processImages() {
        guard !droppedImages.isEmpty else {
            alertItem = AlertItem(
                title: "No Image Selected",
                message: "Please drop an image before converting."
            )
            return
        }
        
        let selectedCount = selectedDevices.filter { $0.value }.count
        guard selectedCount > 0 else {
            alertItem = AlertItem(
                title: "No Devices Selected",
                message: "Please select at least one target device."
            )
            return
        }
        
        isProcessing = true
        totalCount = selectedCount * droppedImages.count
        processedCount = 0
        
        Task {
            await processImagesWithProgress(droppedImages)
        }
    }
    
    private func processImagesWithProgress(_ images: [NSImage]) async {
        let savePanel = NSSavePanel()
        savePanel.title = "Choose Base Directory"
        savePanel.canCreateDirectories = true
        
        await MainActor.run {
            savePanel.begin { response in
                if response == .OK, let baseURL = savePanel.url {
                    Task {
                        var fileCounter = 1
                        
                        for image in images {
                            for (device, isSelected) in self.selectedDevices where isSelected {
                                guard let size = resolutions[device] else { continue }
                                
                                let effectiveOrientation = self.selectedOrientation == .auto ?
                                    determineOrientation(for: image) : self.selectedOrientation
                                
                                let targetSize = calculateTargetSize(
                                    originalSize: image.size,
                                    targetSize: size,
                                    orientation: effectiveOrientation
                                )
                                
                                switch resizeImage(image, to: targetSize) {
                                    case .success(let resizedImage):
                                        let resolution = device.components(separatedBy: "(").last?.dropLast(1) ?? ""
                                        let folderName = "\(device)_\(resolution)"
                                        let folderURL = baseURL.appendingPathComponent(folderName)
                                        
                                        do {
                                            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                                            let fileURL = folderURL.appendingPathComponent("Screen_\(fileCounter).png")
                                            
                                            if case .success(let imageData) = optimizeImage(resizedImage) {
                                                try imageData.write(to: fileURL)
                                                await MainActor.run {
                                                    self.processedCount += 1
                                                }
                                            }
                                        } catch {
                                            print("Error saving image: \(error)")
                                        }
                                    case .failure(let error):
                                        print("Error processing image: \(error)")
                                }
                            }
                            fileCounter += 1
                        }
                        
                        NSSound.beep()
                        await MainActor.run {
                            self.isProcessing = false
                        }
                    }
                }
            }
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
