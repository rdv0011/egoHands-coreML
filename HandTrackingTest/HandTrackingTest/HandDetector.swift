//    Copyright 2020 Dmitry Rybakov
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import UIKit
import CoreML
import Vision
import AVFoundation

class HandDetector {
    public var delegate: (([(label: String, bbox: CGRect)]) -> Void)?

    private let confidenceThreshold: VNConfidence = 0.1
    private let detectorQueue = DispatchQueue(label: "detectorQueue")

    func detectHands(on pixelBuffer: CVPixelBuffer) {
        runRequest(on: pixelBuffer)
    }

    private func request() throws -> VNCoreMLRequest {
        let model = try VNCoreMLModel(for: Hands().model)
        let request = VNCoreMLRequest(model: model, completionHandler: { request, error in
            if let results = request.results as? [VNRecognizedObjectObservation], results.count > 0 {
                self.handleResult(observations: results)
            } else {
                self.delegate?([])
            }
        })
        request.imageCropAndScaleOption = .scaleFill
        return request
    }

    private func handleResult(observations: [VNRecognizedObjectObservation]) {
        for recognizedHand in observations {
            if recognizedHand.confidence > confidenceThreshold {
                let label = recognizedHand.labels.sorted(by: { $0.confidence > $1.confidence }).first?.identifier ?? "unknown"
                delegate?([(label: label, bbox: recognizedHand.boundingBox)])
            }
        }
    }

    private func runRequest(on pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        detectorQueue.async {
            do {
                try handler.perform([self.request()])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
}
