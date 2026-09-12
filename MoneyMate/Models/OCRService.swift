import Foundation
import UIKit
import Vision

// MARK: - 识别结果

struct OCRLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let confidence: Double
    /// 自上而下归一化坐标（0 = 图片顶端）
    let y: Double
}

enum OCRError: LocalizedError {
    case invalidImage
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "图片读不出来，换一张试试"
        case .failed(let message): return "识别失败：" + message
        }
    }
}

// MARK: - Vision 离线文字识别（苹果原生引擎，中英文，无需联网）

enum OCRService {
    static func recognize(image: UIImage) async throws -> [OCRLine] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try recognizeSync(image))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 长图会自动切片识别（带重叠 + 去重），保证小字也能认出来
    static func recognizeSync(_ image: UIImage) throws -> [OCRLine] {
        let base = image.imageOrientation == .up ? image : (redraw(image) ?? image)
        guard let cg = base.cgImage, cg.width > 0, cg.height > 0 else { throw OCRError.invalidImage }

        var lines: [OCRLine] = []
        for tile in slices(of: cg) {
            guard let cropped = cg.cropping(to: tile.rect) else { continue }
            let request = makeRequest()
            let handler = VNImageRequestHandler(cgImage: cropped, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw OCRError.failed(error.localizedDescription)
            }
            let observations = request.results ?? []
            let tileHeight = Double(cropped.height)
            let fullHeight = Double(cg.height)
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let box = observation.boundingBox
                let yFromTop = Double(tile.offsetY) + (1 - Double(box.midY)) * tileHeight
                lines.append(OCRLine(text: candidate.string,
                                     confidence: Double(candidate.confidence),
                                     y: yFromTop / fullHeight))
            }
        }
        return dedupe(lines)
    }

    // MARK: 私有

    private struct Tile {
        let rect: CGRect
        let offsetY: Int
    }

    private static func slices(of cg: CGImage) -> [Tile] {
        let width = cg.width
        let height = cg.height
        let target = max(Int(Double(width) * 2.0), 1400)
        guard height > target + target / 4 else {
            return [Tile(rect: CGRect(x: 0, y: 0, width: width, height: height), offsetY: 0)]
        }
        let tileHeight = min(target, height)
        let step = max(tileHeight - Int(Double(tileHeight) * 0.12), 1)
        var tiles: [Tile] = []
        var y = 0
        while y < height {
            let sliceHeight = min(tileHeight, height - y)
            tiles.append(Tile(rect: CGRect(x: 0, y: y, width: width, height: sliceHeight), offsetY: y))
            if y + sliceHeight >= height { break }
            y += step
        }
        return tiles
    }

    private static func makeRequest() -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let preferred = ["zh-Hans", "zh-Hant", "en-US"]
        let supported = (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
            for: .accurate,
            revision: VNRecognizeTextRequestRevision3)) ?? []
        if supported.isEmpty {
            request.recognitionLanguages = ["zh-Hans", "en-US"]
        } else {
            let usable = preferred.filter { supported.contains($0) }
            request.recognitionLanguages = usable.isEmpty ? supported : usable
        }
        return request
    }

    private static func redraw(_ image: UIImage, maxDimension: CGFloat = 3200) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "").lowercased()
    }

    private static func dedupe(_ lines: [OCRLine]) -> [OCRLine] {
        let sorted = lines.sorted { $0.y < $1.y }
        var result: [OCRLine] = []
        for line in sorted {
            let key = normalize(line.text)
            guard !key.isEmpty else { continue }
            let duplicated = result.suffix(3).contains { existing in
                normalize(existing.text) == key && abs(existing.y - line.y) < 0.005
            }
            if !duplicated { result.append(line) }
        }
        return result
    }
}