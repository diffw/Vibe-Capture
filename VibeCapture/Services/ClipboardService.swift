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
        try copy(images: [image], prompt: prompt)
    }

    /// Clears the pasteboard, then writes images and optional text as separate objects.
    /// This enables multi-image paste support in apps that consume image arrays.
    func copy(images: [NSImage], prompt: String) throws {
        guard !images.isEmpty else {
            throw ClipboardError.writeFailed
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let pb = NSPasteboard.general
        pb.clearContents()

        // Write images and text as separate pasteboard writing objects.
        var objects: [NSPasteboardWriting] = images
        if !trimmed.isEmpty {
            objects.append(prompt as NSString)
        }

        let ok = pb.writeObjects(objects)
        if !ok {
            throw ClipboardError.writeFailed
        }
    }
}



