import AVFoundation
import UIKit // For AVCaptureVideoPreviewLayer
import Combine

struct CameraServiceError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// Data structure to pass sample buffers
struct CameraOutput {
    let sampleBuffer: CMSampleBuffer
    let type: OutputType
    enum OutputType { case videoFront, videoBack, audio }
}

protocol CameraServiceProtocol: AnyObject {
    var cameraOutputPublisher: AnyPublisher<CameraOutput, Never> { get }
    var isSessionRunning: Bool { get }

    func configureSession() -> Future<(frontLayer: AVCaptureVideoPreviewLayer, backLayer: AVCaptureVideoPreviewLayer), Error>
    func startSession()
    func stopSession()
}

class CameraService: NSObject, CameraServiceProtocol, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    private let session = AVCaptureMultiCamSession()
    private let sessionQueue = DispatchQueue(label: "com.jellyjelly.cameraservice.sessionqueue")
    
    private var frontCameraDevice: AVCaptureDevice?
    private var backCameraDevice: AVCaptureDevice?
    private var micDevice: AVCaptureDevice?

    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    private let frontCameraOutput = AVCaptureVideoDataOutput()
    private let backCameraOutput = AVCaptureVideoDataOutput()
    private let audioCaptureOutput = AVCaptureAudioDataOutput()

    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private let _cameraOutputSubject = PassthroughSubject<CameraOutput, Never>()
    var cameraOutputPublisher: AnyPublisher<CameraOutput, Never> {
        _cameraOutputSubject.eraseToAnyPublisher()
    }

    var isSessionRunning: Bool {
        session.isRunning
    }

    override init() {
        super.init()
    }

    func configureSession() -> Future<(frontLayer: AVCaptureVideoPreviewLayer, backLayer: AVCaptureVideoPreviewLayer), Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(CameraServiceError(message: "Self is nil")))
                return
            }
            self.sessionQueue.async {
                self.session.beginConfiguration()

                // Discover devices
                self.frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                self.backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                self.micDevice = AVCaptureDevice.default(for: .audio)

                guard let frontCamera = self.frontCameraDevice,
                      let backCamera = self.backCameraDevice,
                      let mic = self.micDevice else {
                    self.session.commitConfiguration()
                    promise(.failure(CameraServiceError(message: "Required camera or microphone not found.")))
                    return
                }

                do {
                    // Inputs
                    self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                    self.backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                    self.audioInput = try AVCaptureDeviceInput(device: mic)

                    guard let frontInput = self.frontCameraInput, let backInput = self.backCameraInput, let micInput = self.audioInput else {
                        self.session.commitConfiguration()
                        promise(.failure(CameraServiceError(message: "Failed to create camera inputs.")))
                        return
                    }

                    if self.session.canAddInput(frontInput) { self.session.addInput(frontInput) } else { throw CameraServiceError(message: "Cannot add front camera input") }
                    if self.session.canAddInput(backInput) { self.session.addInput(backInput) } else { throw CameraServiceError(message: "Cannot add back camera input") }
                    if self.session.canAddInput(micInput) { self.session.addInput(micInput) } else { throw CameraServiceError(message: "Cannot add audio input") }

                    // Outputs
                    self.frontCameraOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    self.frontCameraOutput.setSampleBufferDelegate(self, queue: self.sessionQueue) // Use sessionQueue for delegate callbacks for consistency
                    if self.session.canAddOutput(self.frontCameraOutput) { self.session.addOutput(self.frontCameraOutput) } else { throw CameraServiceError(message: "Cannot add front camera output") }

                    self.backCameraOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    self.backCameraOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                    if self.session.canAddOutput(self.backCameraOutput) { self.session.addOutput(self.backCameraOutput) } else { throw CameraServiceError(message: "Cannot add back camera output") }
                    
                    self.audioCaptureOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
                    if self.session.canAddOutput(self.audioCaptureOutput) { self.session.addOutput(self.audioCaptureOutput) } else { throw CameraServiceError(message: "Cannot add audio output") }

                    // Preview Layers (must be created on main thread if accessed by UI immediately)
                    // We will create them here and pass them back. The VC will add them to its views.
                    self.frontPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                    self.frontPreviewLayer?.videoGravity = .resizeAspectFill
                    
                    self.backPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                    self.backPreviewLayer?.videoGravity = .resizeAspectFill

                    self.session.commitConfiguration()
                    
                    guard let frontLayer = self.frontPreviewLayer, let backLayer = self.backPreviewLayer else {
                        throw CameraServiceError(message: "Failed to create preview layers.")
                    }
                    promise(.success((frontLayer: frontLayer, backLayer: backLayer)))

                } catch {
                    self.session.commitConfiguration() // Ensure commit on error
                    promise(.failure(error))
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == frontCameraOutput {
            _cameraOutputSubject.send(CameraOutput(sampleBuffer: sampleBuffer, type: .videoFront))
        } else if output == backCameraOutput {
            _cameraOutputSubject.send(CameraOutput(sampleBuffer: sampleBuffer, type: .videoBack))
        } else if output == audioCaptureOutput {
            _cameraOutputSubject.send(CameraOutput(sampleBuffer: sampleBuffer, type: .audio))
        }
    }
}
