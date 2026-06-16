import Foundation
import UIKit
import Vision

/// Validates that a candidate try-on photo shows a full body in a usable pose
/// (spec §5.3: `VNDetectHumanBodyPoseRequest`). On-device, no network.
struct PoseValidator {
    struct Result {
        let isValid: Bool
        let guidance: String?
    }

    /// Minimum joint confidence to count a point as detected.
    private static let minConfidence: Float = 0.3

    func validate(_ image: UIImage) -> Result {
        guard let cgImage = image.cgImage else {
            return Result(isValid: false, guidance: "Couldn't read that image. Try another photo.")
        }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return Result(isValid: false, guidance: "Couldn't analyze the photo. Try another one.")
        }

        guard let observation = request.results?.first else {
            return Result(isValid: false, guidance: "No person detected. Use a clear, full-body photo.")
        }

        // Full body present if we can see upper (shoulders) and lower (ankles) landmarks.
        let recognized = (try? observation.recognizedPoints(.all)) ?? [:]
        func has(_ joint: VNHumanBodyPoseObservation.JointName) -> Bool {
            (recognized[joint]?.confidence ?? 0) >= Self.minConfidence
        }

        let upperBody = has(.leftShoulder) || has(.rightShoulder)
        let lowerBody = has(.leftAnkle) || has(.rightAnkle)

        if upperBody && lowerBody {
            return Result(isValid: true, guidance: nil)
        }
        if upperBody {
            return Result(isValid: false, guidance: "Make sure your full body is visible, including your feet.")
        }
        return Result(isValid: false, guidance: "Stand facing the camera with your whole body in frame, good lighting.")
    }
}
