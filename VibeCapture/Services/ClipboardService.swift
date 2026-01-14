import AppKit

enum ClipboardError: LocalizedError {
    case imageEncodingFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "Failed to encode image."
        case .writeFailed:
            return "Failed to write to clipboard."
        }
    }
}

final class ClipboardService {
    static let shared = ClipboardService()
    private init() {}

    /// Clears the pasteboard, then writes image and text as separate objects.
    /// This allows apps like Cursor to potentially read both.
    func copy(image: NSImage, prompt: String) throws {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let pb = NSPasteboard.general
        pb.clearContents()

        // Write image and text as separate pasteboard writing objects
        var objects: [NSPasteboardWriting] = [image]
        if !trimmed.isEmpty {
            objects.append(prompt as NSString)
        }

        let ok = pb.writeObjects(objects)
        if !ok {
            throw ClipboardError.writeFailed
        }
    }
}



