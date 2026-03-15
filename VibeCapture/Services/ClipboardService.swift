import AppKit

enum ClipboardError: LocalizedError {
    case imageEncodingFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return L("error.image_encoding_failed")
        case .writeFailed:
            return L("error.clipboard_write_failed")
        }
    }
}

final class ClipboardService {
    static let shared = ClipboardService()
    private init() {}

    /// Clears the pasteboard, then writes image and text as separate objects.
    /// This allows apps like Cursor to potentially read both.
    func copy(image: NSImage, prompt: String) throws {
        try copy(images: [image], fileURLs: [], prompt: prompt)
    }

    /// Clears the pasteboard, then writes images and optional text as separate objects.
    /// Each image item can carry both file-url and bitmap reps so different apps
    /// (native / web wrappers / chat clients) can consume the format they support.
    func copy(images: [NSImage], fileURLs: [URL] = [], prompt: String) throws {
        guard !images.isEmpty || !fileURLs.isEmpty else {
            throw ClipboardError.writeFailed
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageItems = makeImagePasteboardItems(images: images, fileURLs: fileURLs)
        guard !imageItems.isEmpty else {
            throw ClipboardError.writeFailed
        }

        let pb = NSPasteboard.general
        pb.clearContents()

        // Write one pasteboard item per image/file.
        var objects: [NSPasteboardWriting] = imageItems
        if !trimmed.isEmpty {
            objects.append(prompt as NSString)
        }

        let ok = pb.writeObjects(objects)
        if !ok {
            throw ClipboardError.writeFailed
        }
    }

    private func makeImagePasteboardItems(images: [NSImage], fileURLs: [URL]) -> [NSPasteboardItem] {
        if !fileURLs.isEmpty {
            return fileURLs.enumerated().compactMap { index, fileURL in
                let item = NSPasteboardItem()
                item.setString(fileURL.absoluteString, forType: .fileURL)

                let image: NSImage?
                if index < images.count {
                    image = images[index]
                } else {
                    image = NSImage(contentsOf: fileURL)
                }

                if let pngData = image?.pngData() {
                    item.setData(pngData, forType: .png)
                }
                if let tiffData = image?.tiffRepresentation {
                    item.setData(tiffData, forType: .tiff)
                }
                return item
            }
        }

        return images.compactMap { image in
            let item = NSPasteboardItem()
            if let pngData = image.pngData() {
                item.setData(pngData, forType: .png)
            }
            if let tiffData = image.tiffRepresentation {
                item.setData(tiffData, forType: .tiff)
            }
            return item.types.isEmpty ? nil : item
        }
    }
}



