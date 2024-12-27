//
//  HelpFunc.swift
//  ImageConvertASConnect
//
//  Created by Anatolii Kravchuk on 27.12.2024.
//

import AppKit
import Foundation
import SwiftUI


// MARK: - Types & Constants
enum ImageProcessingError: LocalizedError {
    case invalidImage
    case conversionFailed
    case invalidSize
    case compressionFailed
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format or corrupted image data"
        case .conversionFailed:
            return "Failed to convert image to required format"
        case .invalidSize:
            return "Invalid target size specified"
        case .compressionFailed:
            return "Failed to compress image"
        case .saveFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        }
    }
}

struct DeviceSpec {
    let name: String
    let size: CGSize
    let scale: CGFloat
    
    var scaledSize: CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }
}

// MARK: - Device Specifications
let resolutions: [String: CGSize] = [
    "iPhone 6.9\" (1290x2796)": CGSize(width: 1290, height: 2796),
    "iPhone 6.5\" (1284x2778)": CGSize(width: 1284, height: 2778),
    "iPad 13\" (2064x2752)": CGSize(width: 2064, height: 2752),
    "iPad 12.9\" (2048x2732)": CGSize(width: 2048, height: 2732),
    "New Device (1920x1080)": CGSize(width: 1920, height: 1080)
]

let deviceSpecs: [DeviceSpec] = [
    DeviceSpec(name: "iPhone 6.9\" (1290x2796)", size: CGSize(width: 1290, height: 2796), scale: 3.0),
    DeviceSpec(name: "iPhone 6.5\" (1284x2778)", size: CGSize(width: 1284, height: 2778), scale: 3.0),
    DeviceSpec(name: "iPad 13\" (2064x2752)", size: CGSize(width: 2064, height: 2752), scale: 2.0),
    DeviceSpec(name: "iPad 12.9\" (2048x2732)", size: CGSize(width: 2048, height: 2732), scale: 2.0),
    DeviceSpec(name: "New Device (1920x1080)", size: CGSize(width: 1920, height: 1080), scale: 1.0)
]

// MARK: - Orientation
enum Orientation: String, CaseIterable, Identifiable {
    case auto
    case horizontal
    case vertical
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .auto: return "Auto"
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        }
    }
}

// MARK: - Image Processing Functions
func resizeImage(_ image: NSImage, to targetSize: CGSize) -> Result<NSImage, ImageProcessingError> {
    // Create bitmap with specific pixel dimensions
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(targetSize.width),
        pixelsHigh: Int(targetSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaFirst,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return .failure(.conversionFailed)
    }

    bitmapRep.size = targetSize
    
    NSGraphicsContext.current?.imageInterpolation = .high
    
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    
    image.draw(in: NSRect(origin: .zero, size: targetSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    
    NSGraphicsContext.restoreGraphicsState()
    
    let newImage = NSImage(size: targetSize)
    newImage.addRepresentation(bitmapRep)
    
    return .success(newImage)
}

func optimizeImage(_ image: NSImage, compression: Float = 0.8) -> Result<Data, ImageProcessingError> {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return .failure(.conversionFailed)
    }
    
    guard let data = bitmap.representation(using: .jpeg,
                                         properties: [.compressionFactor: NSNumber(value: compression)]) else {
        return .failure(.compressionFailed)
    }
    
    return .success(data)
}

// MARK: - Save Functions
func saveImageWithDialog(_ image: NSImage, named deviceName: String) {
    let savePanel = NSSavePanel()
    savePanel.title = "Save Resized Image"
    
    // Extract resolution from device name
    let resolution = deviceName.components(separatedBy: "(").last?.dropLast(1) ?? ""
    let folderName = "\(deviceName)_\(resolution)"
    
    // Set initial directory
    if let baseURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
        let folderURL = baseURL.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            savePanel.directoryURL = folderURL
            savePanel.nameFieldStringValue = "Screen_1.png"
            savePanel.allowedFileTypes = ["png"]
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    switch optimizeImage(image) {
                    case .success(let imageData):
                        do {
                            try imageData.write(to: url)
                            print("✅ Saved \(deviceName) image at \(url)")
                        } catch {
                            print("❌ Failed to save image: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        print("❌ Failed to optimize image: \(error)")
                    }
                }
            }
        } catch {
            print("❌ Failed to create directory: \(error)")
        }
    }
}

// MARK: - Utility Functions
func determineOrientation(for image: NSImage) -> Orientation {
    let orientation = image.size.width > image.size.height ? Orientation.horizontal : Orientation.vertical
    print("Detected orientation: \(orientation)")
    return orientation
}

func calculateAspectRatio(for size: CGSize) -> CGFloat {
    guard size.height > 0 else { return 0 }
    return size.width / size.height
}

// MARK: - Image Validation
func validateImage(_ image: NSImage) -> Result<Void, ImageProcessingError> {
    guard image.size.width > 0 && image.size.height > 0 else {
        return .failure(.invalidImage)
    }
    
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return .failure(.invalidImage)
    }
    
    return .success(())
}

// MARK: - Size Calculations

// MARK: - Size Calculations

func calculateTargetSize(originalSize: CGSize, targetSize: CGSize, orientation: Orientation) -> CGSize {
    switch orientation {
    case .horizontal:
        return CGSize(
            width: max(targetSize.width, targetSize.height),
            height: min(targetSize.width, targetSize.height)
        )
    case .vertical:
        return CGSize(
            width: min(targetSize.width, targetSize.height),
            height: max(targetSize.width, targetSize.height)
        )
    case .auto:
        return targetSize
    }
}

// MARK: - NSImage Extensions
extension NSImage {
    var aspectRatio: CGFloat {
        calculateAspectRatio(for: size)
    }
    
    func resizedWithAspectRatio(to targetSize: CGSize) -> Result<NSImage, ImageProcessingError> {
        let aspectRatio = self.aspectRatio
        let newSize: CGSize
        
        if targetSize.width / targetSize.height > aspectRatio {
            newSize = CGSize(
                width: targetSize.height * aspectRatio,
                height: targetSize.height
            )
        } else {
            newSize = CGSize(
                width: targetSize.width,
                height: targetSize.width / aspectRatio
            )
        }
        
        return resizeImage(self, to: newSize)
    }
}
