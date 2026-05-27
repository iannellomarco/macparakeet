import Foundation
import Vision

// MARK: - OCR Result

public struct OCRResult: Sendable {
    public let text: String
    public let confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

// MARK: - Protocol

public protocol ScreenshotOCRServiceProtocol: Sendable {
    func extractText(from imageData: Data) async throws -> OCRResult
}

// MARK: - Implementation

public final class ScreenshotOCRService: ScreenshotOCRServiceProtocol {
    private let queue: DispatchQueue

    public init() {
        self.queue = DispatchQueue(label: "com.macparakeet.journal.ocr", qos: .utility)
    }

    public func extractText(from imageData: Data) async throws -> OCRResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let cgImage = self.createCGImage(from: imageData) else {
                    continuation.resume(returning: OCRResult(text: "", confidence: 0))
                    return
                }

                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let result = self.processResults(request.results)
                    continuation.resume(returning: result)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["en"]

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func createCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        return cgImage
    }

    private func processResults(_ results: [Any]?) -> OCRResult {
        guard let observations = results as? [VNRecognizedTextObservation],
              !observations.isEmpty
        else {
            return OCRResult(text: "", confidence: 0)
        }

        var allText = ""
        var totalConfidence: Float = 0
        var count: Float = 0

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            // Add newline between lines that are visually separated
            if !allText.isEmpty {
                // Check bounding box: if this line starts significantly
                // below the previous one, add a newline
                allText += "\n"
            }
            allText += topCandidate.string
            totalConfidence += Float(topCandidate.confidence)
            count += 1
        }

        let avgConfidence = count > 0 ? totalConfidence / count : 0
        return OCRResult(text: allText, confidence: avgConfidence)
    }
}
