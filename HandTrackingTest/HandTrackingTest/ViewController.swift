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

    private var videoDevice: AVCaptureDevice!
    private var videoConnection: AVCaptureConnection!
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private var cameraDeviceInput: AVCaptureDeviceInput?
    private let cameraVideoDataOutput = AVCaptureVideoDataOutput()
    private let cameraDataOutputQueue = DispatchQueue(label: "cameraOutputQueue", attributes: [], autoreleaseFrequency: .workItem)
    private var handDetectorWorking = false
    private var viewSize: CGSize = .zero

    private let session = AVCaptureMultiCamSession()
    private let handDetector = HandDetector()
    private var cameraDevicePosition: AVCaptureDevice.Position = .back

    lazy var videoPreviewLayer: AVCaptureVideoPreviewLayer = {
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.frame = self.view.layer.bounds
        previewLayer.contentsGravity = CALayerContentsGravity.resizeAspectFill
        previewLayer.videoGravity = .resizeAspect
        self.view.layer.insertSublayer(previewLayer, at: 0)
        return previewLayer
    } ()

    override func viewDidLoad() {
        super.viewDidLoad()

        videoPreviewLayer.setSessionWithNoConnection(session)
        handDetector.delegate = processDetectedHands
        viewSize = view.bounds.size

        checkCameraAuthorization() { granted in
            if granted {
                self.configuration()
            }
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            fatalError()
        }
        if !handDetectorWorking {
            handDetectorWorking = true

            let orientation = CGImagePropertyOrientation(rawValue: UInt32(exifOrientationFromDeviceOrientation()))!
            handDetector.detectHands(on: imageBuffer, orientation: orientation)
        }
    }
}

extension ViewController {
    func processDetectedHands(detectedHands: [(label: String, bbox: CGRect)]) {
        cameraDataOutputQueue.async {
            self.handDetectorWorking = false
        }
        guard detectedHands.count > 0 else {
            return
        }
        let translate = CGAffineTransform(scaleX: 1, y: -1)
        let scale = CGAffineTransform.identity.scaledBy(x: viewSize.width, y: viewSize.height)
        let translate2 = CGAffineTransform.identity.translatedBy(x: 0, y: viewSize.height)
        let rectsWithColor = detectedHands.map {
            (UIColor.red, $0.bbox.applying(translate).applying(scale).applying(translate2))
        }
        DispatchQueue.main.async {
            print(rectsWithColor)
            self.draw(rects: rectsWithColor, on: self.view)
        }
    }

    public func draw(rects: [(UIColor, CGRect)], on view: UIView) {
        var layers = [CAShapeLayer]()
        rects.forEach { color, rect in
            let overlayLayer = CAShapeLayer()
            overlayLayer.fillColor = UIColor.clear.cgColor
            overlayLayer.strokeColor = color.cgColor
            let combined = CGMutablePath()
            let circlePath = UIBezierPath(roundedRect: rect, cornerRadius: 0.0)
            combined.addPath(circlePath.cgPath)
            overlayLayer.path = combined
            layers.append(overlayLayer)
        }
        view.layer.sublayers?.forEach{ l in
            if l is CAShapeLayer {
                l.removeFromSuperlayer()
            }
        }
        layers.forEach { view.layer.addSublayer($0) }
    }
}

extension ViewController {
    private func checkCameraAuthorization(_ completion: @escaping ((Bool) -> Void)) {
        let cameraMediaType = AVMediaType.video
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: cameraMediaType)

        switch cameraAuthorizationStatus {
        case .denied: completion(false)
        case .authorized: completion(true)
        case .restricted: completion(false)

        case .notDetermined:
            // Prompting user for the permission to use the camera.
            AVCaptureDevice.requestAccess(for: cameraMediaType) { granted in
                completion(granted)
            }
        default: completion(false)
        }
    }

    func configuration() {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCam not supported on this device")
            return
        }

        session.beginConfiguration()
        print(configureCamera())
        session.commitConfiguration()

        session.startRunning()
    }

    private func configureCamera() -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Could not find the back camera")
            return false
        }

        // Add the back camera input to the session
        do {
            cameraDeviceInput = try AVCaptureDeviceInput(device: camera)

            guard let cameraDeviceInput = cameraDeviceInput,
                session.canAddInput(cameraDeviceInput) else {
                    print("Could not add back camera device input")
                    return false
            }
            session.addInputWithNoConnections(cameraDeviceInput)
        } catch {
            print("Could not create back camera device input: \(error)")
            return false
        }

        // Find the back camera device input's video port
        guard let cameraDeviceInput = cameraDeviceInput,
            let cameraVideoPort = cameraDeviceInput.ports(for: .video,
                                                          sourceDeviceType: camera.deviceType,
                                                          sourceDevicePosition: camera.position).first else {
                print("Could not find the back camera device input's video port")
                return false
        }

        // Add the back camera video data output
        guard session.canAddOutput(cameraVideoDataOutput) else {
            print("Could not add the back camera video data output")
            return false
        }
        session.addOutputWithNoConnections(cameraVideoDataOutput)
        cameraVideoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        cameraVideoDataOutput.setSampleBufferDelegate(self, queue: cameraDataOutputQueue)
        cameraVideoDataOutput.alwaysDiscardsLateVideoFrames = true

        let cameraVideoDataOutputConnection = AVCaptureConnection(inputPorts: [cameraVideoPort], output: cameraVideoDataOutput)
        guard session.canAddConnection(cameraVideoDataOutputConnection) else {
            print("Could not add a connection to the back camera video data output")
            return false
        }

        session.addConnection(cameraVideoDataOutputConnection)
        cameraVideoDataOutputConnection.videoOrientation = .portrait


        let cameraVideoPreviewLayerConnection = AVCaptureConnection(inputPort: cameraVideoPort, videoPreviewLayer: self.videoPreviewLayer )
        session.addConnection(cameraVideoPreviewLayerConnection)

        return true
    }
}

extension ViewController {
    func exifOrientationFromDeviceOrientation() -> UInt32 {
        enum DeviceOrientation: UInt32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        var exifOrientation: DeviceOrientation

        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = cameraDevicePosition == .front ? .bottom0ColRight : .top0ColLeft
        case .landscapeRight:
            exifOrientation = cameraDevicePosition == .front ? .top0ColLeft : .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
}
