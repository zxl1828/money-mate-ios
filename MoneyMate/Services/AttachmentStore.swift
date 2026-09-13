import Foundation
import UIKit

/// 收据 / 发票附件的本地存储（Documents/Attachments）
enum AttachmentStore {

    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Attachments", isDirectory: true)
    }

    private static func ensureDirectory() -> Bool {
        let url = directory
        if FileManager.default.fileExists(atPath: url.path) { return true }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func save(data: Data, isImage: Bool) -> TxAttachment? {
        guard ensureDirectory() else { return nil }
        var payload = data
        var ext = "dat"
        if isImage {
            if let image = UIImage(data: data), let compressed = compress(image) {
                payload = compressed
                ext = "jpg"
            } else {
                ext = "jpg"
            }
        }
        let fileName = UUID().uuidString + "." + ext
        let url = directory.appendingPathComponent(fileName)
        do {
            try payload.write(to: url, options: .atomic)
            return TxAttachment(fileName: fileName, isImage: isImage)
        } catch {
            return nil
        }
    }

    static func url(for attachment: TxAttachment) -> URL {
        directory.appendingPathComponent(attachment.fileName)
    }

    static func exists(_ attachment: TxAttachment) -> Bool {
        FileManager.default.fileExists(atPath: url(for: attachment).path)
    }

    static func loadImage(_ attachment: TxAttachment) -> UIImage? {
        UIImage(contentsOfFile: url(for: attachment).path)
    }

    static func delete(_ attachment: TxAttachment) {
        try? FileManager.default.removeItem(at: url(for: attachment))
    }

    static func deleteAll(of attachments: [TxAttachment]) {
        for item in attachments { delete(item) }
    }

    /// 长边压到 1600 以内再转 JPEG
    private static func compress(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)
        var target = image
        if longest > maxSide {
            let scale = maxSide / longest
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            target = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        return target.jpegData(compressionQuality: 0.8)
    }
}
