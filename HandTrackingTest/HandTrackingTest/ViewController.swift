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
import AVFoundation

class ViewController: UIViewController {

    private lazy var cameraView: CameraView = { CameraView() }()
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)

    // MARK:- Camera Type
    private let cameraDeviceType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
    private let cameraDevicePosition = AVCaptureDevice.Position.back

    private var cameraFeedSession: AVCaptureSession?

    private let handDetector = HandDetector()
    private var handDetectorWorking = false

    override func loadView() {
        view = cameraView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        handDetector.delegate = processDetectedHands
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            if cameraFeedSession == nil {
                cameraView.previewLayer.videoGravity = .resizeAspectFill
                try setupAVSession()
                cameraView.previewLayer.session = cameraFeedSession
            }
            cameraFeedSession?.startRunning()
        } catch {
            AppError.display(error, inViewController: self)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewWillDisappear(animated)
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            fatalError()
        }
        if !handDetectorWorking {
            handDetectorWorking = true

            handDetector.detectHands(on: imageBuffer)
        }
    }
}

extension ViewController {
    func processDetectedHands(detectedHands: [(label: String, bbox: CGRect)]) {
        videoDataOutputQueue.async {
            self.handDetectorWorking = false
        }
        guard detectedHands.count > 0 else {
            return
        }
        DispatchQueue.main.async {
            let translate = CGAffineTransform(scaleX: 1, y: -1)
            let scale = CGAffineTransform.identity.scaledBy(x: self.cameraView.bounds.size.width,
                                                            y: self.cameraView.bounds.size.height)
            let translate2 = CGAffineTransform.identity.translatedBy(x: 0, y: self.cameraView.bounds.size.height)
            let rects = detectedHands.map {
                (UIColor.red, $0.bbox.applying(translate).applying(scale).applying(translate2))
            }
            self.cameraView.showRects(rects)
        }
    }
}

extension ViewController {
    func setupAVSession() throws {
        // Select a camera device
        guard let videoDevice = AVCaptureDevice.default(cameraDeviceType, for: .video, position: cameraDevicePosition) else {
            throw HandTrackingError.captureSessionSetup(reason: "Could not find a front facing camera.")
        }

        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            throw HandTrackingError.captureSessionSetup(reason: "Could not create video device input.")
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high

        // Add a video input.
        guard session.canAddInput(deviceInput) else {
            throw HandTrackingError.captureSessionSetup(reason: "Could not add video device input to the session")
        }
        session.addInput(deviceInput)

        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            // Add a video data output.
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            throw HandTrackingError.captureSessionSetup(reason: "Could not add video data output to the session")
        }
        session.commitConfiguration()
        cameraFeedSession = session
    }
}
