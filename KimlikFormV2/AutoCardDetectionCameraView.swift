import SwiftUI
import AVFoundation
import Vision
import UIKit

// MARK: - UIKit Controller for Camera, Vision Processing
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var photoOutput: AVCapturePhotoOutput!
    private var detectionOverlay: CALayer!
    
    private var lastObservedRectangle: VNRectangleObservation?
    private var isCardStable = false
    private var stableFrameCount = 0
    private let requiredStableFrames = 30
    private let debugMode = true
    
    var onCardDetectionChange: ((Bool) -> Void)?
    var onPhotoTaken: ((UIImage?) -> Void)?
    var isDetectingActive = true
    var manualPhotoRequested = false {
        didSet {
            if manualPhotoRequested {
                capturePhoto()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupDetectionOverlay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.global(qos: .background).async {
                self.captureSession.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.global(qos: .background).async {
                        self.captureSession.startRunning()
                    }
                }
            }
        case .denied, .restricted:
            print("Kamera izni reddedildi.")
        @unknown default:
            break
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
            try? videoDevice.lockForConfiguration()
            videoDevice.focusMode = .continuousAutoFocus
            if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                videoDevice.exposureMode = .continuousAutoExposure
            }
            videoDevice.unlockForConfiguration()
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }
    
    private func setupDetectionOverlay() {
        detectionOverlay = CALayer()
        detectionOverlay.frame = view.bounds
        detectionOverlay.position = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view.layer.addSublayer(detectionOverlay)
    }
    
    // MARK: - Video Karelerinde Kart Tespiti
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isDetectingActive, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectRectanglesRequest { [weak self] (request, error) in
            guard let self = self else { return }
            guard error == nil else {
                print("Dikdörtgen tespit hatası: \(error!.localizedDescription)")
                return
            }
            
            if let results = request.results as? [VNRectangleObservation], !results.isEmpty {
                self.processRectangleDetection(request)
            } else {
                self.tryWithSlightContrast(pixelBuffer: pixelBuffer)
            }
        }
        
        request.minimumAspectRatio = 1.5
        request.maximumAspectRatio = 1.7
        request.minimumSize = 0.2
        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        
        let imageOrientation: CGImagePropertyOrientation = .up
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation)
        try? handler.perform([request])
    }
    
    private func tryWithSlightContrast(pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let filter = CIFilter(name: "CIColorControls") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.15, forKey: kCIInputContrastKey)
        
        guard let outputImage = filter.outputImage else { return }
        
        let context = CIContext(options: [.useSoftwareRenderer: false])
        var enhancedPixelBuffer: CVPixelBuffer?
        
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            attributes,
            &enhancedPixelBuffer
        )
        
        guard status == kCVReturnSuccess, let outputBuffer = enhancedPixelBuffer else { return }
        
        context.render(outputImage, to: outputBuffer)
        
        let backupRequest = VNDetectRectanglesRequest { [weak self] (request, error) in
            guard let self = self else { return }
            guard error == nil else { return }
            self.processRectangleDetection(request, isBackup: true)
        }
        
        backupRequest.minimumAspectRatio = 1.5
        backupRequest.maximumAspectRatio = 1.7
        backupRequest.minimumSize = 0.2
        backupRequest.minimumConfidence = 0.7
        backupRequest.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: outputBuffer, orientation: .up)
        try? handler.perform([backupRequest])
    }
    
    private func processRectangleDetection(_ request: VNRequest, isBackup: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectionOverlay.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            guard let results = request.results as? [VNRectangleObservation],
                  let observation = results.first else {
                if self.isCardStable {
                    self.isCardStable = false
                    self.stableFrameCount = 0
                    self.onCardDetectionChange?(false)
                }
                return
            }
            
            self.drawRectangleOutline(observation, isBackup: isBackup)
            
            if !self.isCardStable {
                self.isCardStable = true
                self.onCardDetectionChange?(true)
            }
            
            if self.isCardStableBetweenFrames(observation) {
                self.stableFrameCount += 1
                if self.stableFrameCount >= self.requiredStableFrames {
                    self.capturePhotoWithCurrentRectangle(observation)
                    self.stableFrameCount = 0
                }
            } else {
                self.stableFrameCount = 0
            }
        }
    }
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            print("Fotoğraf çıkışı bulunamadı")
            return
        }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func capturePhotoWithCurrentRectangle(_ observation: VNRectangleObservation) {
        lastObservedRectangle = observation
        capturePhoto()
    }
    
    private func isCardStableBetweenFrames(_ currentObservation: VNRectangleObservation) -> Bool {
        guard let lastRect = lastObservedRectangle else {
            lastObservedRectangle = currentObservation
            return false
        }
        let threshold: CGFloat = 0.015
        let topLeftDiff = abs(currentObservation.topLeft.x - lastRect.topLeft.x) + abs(currentObservation.topLeft.y - lastRect.topLeft.y)
        let topRightDiff = abs(currentObservation.topRight.x - lastRect.topRight.x) + abs(currentObservation.topRight.y - lastRect.topRight.y)
        let bottomLeftDiff = abs(currentObservation.bottomLeft.x - lastRect.bottomLeft.x) + abs(currentObservation.bottomLeft.y - lastRect.bottomLeft.y)
        let bottomRightDiff = abs(currentObservation.bottomRight.x - lastRect.bottomRight.x) + abs(currentObservation.bottomRight.y - lastRect.bottomRight.y)
        let stable = topLeftDiff < threshold && topRightDiff < threshold && bottomLeftDiff < threshold && bottomRightDiff < threshold
        lastObservedRectangle = currentObservation
        return stable
    }
    
    private func drawRectangleOutline(_ observation: VNRectangleObservation, isBackup: Bool = false) {
        let rectangleLayer = CAShapeLayer()
        rectangleLayer.strokeColor = isBackup ? UIColor.cyan.cgColor : UIColor.green.cgColor
        rectangleLayer.fillColor = UIColor.clear.cgColor
        rectangleLayer.lineWidth = 3

        let topLeft = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y))
        let topRight = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y))
        let bottomLeft = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y))
        let bottomRight = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y))

        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()
        rectangleLayer.path = path.cgPath
        detectionOverlay.addSublayer(rectangleLayer)

        let guideLayer = CAShapeLayer()
        guideLayer.fillColor = UIColor.clear.cgColor
        guideLayer.strokeColor = UIColor.white.withAlphaComponent(0.8).cgColor
        guideLayer.lineWidth = 2
        guideLayer.lineDashPattern = [6, 4]
        guideLayer.path = path.cgPath
        detectionOverlay.addSublayer(guideLayer)
        
        let textLayer = CATextLayer()
        let backupIndicator = isBackup ? " (B)" : ""
        if stableFrameCount > 0 {
            textLayer.string = "Kartı sabit tutun: \(stableFrameCount)/\(requiredStableFrames)\(backupIndicator)"
            textLayer.foregroundColor = stableFrameCount >= requiredStableFrames-5 ? UIColor.green.cgColor : UIColor.yellow.cgColor
        } else {
            textLayer.string = "Kartı çerçeveye tam oturtun\(backupIndicator)"
            textLayer.foregroundColor = UIColor.white.cgColor
        }
        textLayer.fontSize = 20
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: 20, y: view.bounds.height - 120, width: view.bounds.width - 40, height: 40)
        textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.7).cgColor
        textLayer.cornerRadius = 8
        textLayer.contentsScale = UIScreen.main.scale
        detectionOverlay.addSublayer(textLayer)
    }
    
    private func cropImageToCardBoundaries(_ inputImage: UIImage, observation: VNRectangleObservation) -> UIImage? {
        guard let cgImage = inputImage.cgImage else { return nil }
        
        let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        
        let tl = CGPoint(
            x: observation.topLeft.x * imageSize.width,
            y: (1 - observation.topLeft.y) * imageSize.height
        )
        let tr = CGPoint(
            x: observation.topRight.x * imageSize.width,
            y: (1 - observation.topRight.y) * imageSize.height
        )
        let bl = CGPoint(
            x: observation.bottomLeft.x * imageSize.width,
            y: (1 - observation.bottomLeft.y) * imageSize.height
        )
        let br = CGPoint(
            x: observation.bottomRight.x * imageSize.width,
            y: (1 - observation.bottomRight.y) * imageSize.height
        )
        
        let correctedImage = perspectiveCorrection(
            inputImage: inputImage,
            topLeft: tl,
            topRight: tr,
            bottomLeft: bl,
            bottomRight: br
        )
        
        return rotateToLandscape(correctedImage ?? inputImage)
    }
    
    private func perspectiveCorrection(inputImage: UIImage, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> UIImage? {
        guard let cgImage = inputImage.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            return inputImage
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        let imageHeight = ciImage.extent.height
        
        let ciTopLeft = CGPoint(x: topLeft.x, y: imageHeight - topLeft.y)
        let ciTopRight = CGPoint(x: topRight.x, y: imageHeight - topRight.y)
        let ciBottomLeft = CGPoint(x: bottomLeft.x, y: imageHeight - bottomLeft.y)
        let ciBottomRight = CGPoint(x: bottomRight.x, y: imageHeight - bottomRight.y)
        
        filter.setValue(CIVector(cgPoint: ciTopLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: ciTopRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: ciBottomRight), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: ciBottomLeft), forKey: "inputBottomLeft")
        
        guard let outputCIImage = filter.outputImage else {
            return inputImage
        }
        
        let context = CIContext(options: [
            .useSoftwareRenderer: false,
            .priorityRequestLow: false
        ])
        
        guard let cgImageResult = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return inputImage
        }
        
        let resultImage = UIImage(cgImage: cgImageResult, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        
        return resultImage
    }
    
    private func rotateToLandscape(_ image: UIImage) -> UIImage {
        if image.size.width > image.size.height {
            return image
        }
        
        let radians = CGFloat(90 * Double.pi / 180)
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        
        let rect = CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height)
        context.draw(image.cgImage!, in: rect)
        
        guard let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        
        return rotatedImage
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Fotoğraf çekme hatası: \(error!.localizedDescription)")
            onPhotoTaken?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData) else {
            print("Fotoğraf dönüştürme hatası")
            onPhotoTaken?(nil)
            return
        }
        
        if let savedObservation = lastObservedRectangle {
            if let croppedImage = cropImageToCardBoundaries(capturedImage, observation: savedObservation) {
                onPhotoTaken?(croppedImage)
            } else {
                detectAndCropCard(in: capturedImage)
            }
        } else {
            detectAndCropCard(in: capturedImage)
        }
    }
    
    private func detectAndCropCard(in image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            onPhotoTaken?(rotateToLandscape(image))
            return
        }
        
        let orientation: CGImagePropertyOrientation
        switch image.imageOrientation {
        case .up: orientation = .up
        case .down: orientation = .down
        case .left: orientation = .left
        case .right: orientation = .right
        case .upMirrored: orientation = .upMirrored
        case .downMirrored: orientation = .downMirrored
        case .leftMirrored: orientation = .leftMirrored
        case .rightMirrored: orientation = .rightMirrored
        @unknown default: orientation = .up
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        
        let request = VNDetectRectanglesRequest { [weak self] (req, err) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let rect = (req.results as? [VNRectangleObservation])?.first {
                    if let croppedImage = self.cropImageToCardBoundaries(image, observation: rect) {
                        self.onPhotoTaken?(croppedImage)
                    } else {
                        self.onPhotoTaken?(self.rotateToLandscape(image))
                    }
                } else {
                    self.onPhotoTaken?(self.rotateToLandscape(image))
                }
            }
        }
        
        request.minimumAspectRatio = 1.5
        request.maximumAspectRatio = 1.7
        request.minimumSize = 0.2
        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Vision request hatası: \(error)")
                DispatchQueue.main.async {
                    self.onPhotoTaken?(self.rotateToLandscape(image))
                }
            }
        }
    }
}

// MARK: - SwiftUI Wrapper (iPad İçin Fullscreen)
struct AutoCardDetectionCameraView: UIViewControllerRepresentable {
    @Binding var isDetecting: Bool
    var onPhotoTaken: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        
        // iPad için zorla fullscreen
        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.modalPresentationStyle = .fullScreen
        }
        
        controller.onCardDetectionChange = { isDetected in
            self.isDetecting = isDetected
        }
        controller.onPhotoTaken = onPhotoTaken
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // iPad için runtime'da da fullscreen ayarla
        if UIDevice.current.userInterfaceIdiom == .pad {
            uiViewController.modalPresentationStyle = .fullScreen
        }
    }
}
