import Foundation
import AVFoundation
import Combine
import UIKit // For UIImage for record button

enum RecordingState: Equatable {
    case idle
    case starting
    case recording
    case stopping
    case saving
    case error(String)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.starting, .starting):
            return true
        case (.recording, .recording):
            return true
        case (.stopping, .stopping):
            return true
        case (.saving, .saving):
            return true
        case (.error(let lError), .error(let rError)):
            return lError == rError
        default:
            return false
        }
    }
}

protocol CameraViewModelProtocol: AnyObject {
    var recordingStatePublisher: AnyPublisher<RecordingState, Never> { get }
    var recordButtonImageNamePublisher: AnyPublisher<String, Never> { get }
    var showToastPublisher: AnyPublisher<(message: String, duration: TimeInterval), Never> { get }
    var navigateToTabPublisher: AnyPublisher<Int, Never> { get }
    var frontPreviewLayer: AVCaptureVideoPreviewLayer? { get }
    var backPreviewLayer: AVCaptureVideoPreviewLayer? { get }
    var recordingProgressPublisher: AnyPublisher<Float, Never> { get }

    func viewDidLoad()
    func toggleRecording()
    func setupPreviewLayersInViews(frontView: UIView, backView: UIView)
    func viewDidLayoutSubviews()
}

class CameraViewModel: CameraViewModelProtocol {
    private let cameraService: CameraServiceProtocol
    private let videoProcessingService: VideoProcessingServiceProtocol
    private let photoLibraryService: PhotoLibraryServiceProtocol

    private let _recordingStateSubject = CurrentValueSubject<RecordingState, Never>(.idle)
    var recordingStatePublisher: AnyPublisher<RecordingState, Never> { _recordingStateSubject.eraseToAnyPublisher() }

    private let _recordButtonImageNameSubject = CurrentValueSubject<String, Never>("recording")
    var recordButtonImageNamePublisher: AnyPublisher<String, Never> { _recordButtonImageNameSubject.eraseToAnyPublisher() }
    
    private let _showToastSubject = PassthroughSubject<(message: String, duration: TimeInterval), Never>()
    var showToastPublisher: AnyPublisher<(message: String, duration: TimeInterval), Never> { _showToastSubject.eraseToAnyPublisher() }

    private let _navigateToTabSubject = PassthroughSubject<Int, Never>()
    var navigateToTabPublisher: AnyPublisher<Int, Never> { _navigateToTabSubject.eraseToAnyPublisher() }

    private let _recordingProgressSubject = CurrentValueSubject<Float, Never>(0.0)
    var recordingProgressPublisher: AnyPublisher<Float, Never> { _recordingProgressSubject.eraseToAnyPublisher() }

    private(set) var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private(set) var backPreviewLayer: AVCaptureVideoPreviewLayer?

    private var assetWriter: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outputURL: URL!
    private var currentRecordingStartTime: CMTime?
    private var recordingTimer: Timer?
    private let recordingDuration: TimeInterval = 15.0

    // CHANGE: CPOixelBuffer -> CVPixelBuffer
    private var frontBuffer: CVPixelBuffer?
    private var backBuffer: CVPixelBuffer?
    
    private var cancellables = Set<AnyCancellable>()
    private let albumName = "Jelly Jelly Videos"

    init(cameraService: CameraServiceProtocol,
         videoProcessingService: VideoProcessingServiceProtocol,
         photoLibraryService: PhotoLibraryServiceProtocol) {
        self.cameraService = cameraService
        self.videoProcessingService = videoProcessingService
        self.photoLibraryService = photoLibraryService
        subscribeToCameraOutput()
    }

    func viewDidLoad() {
        _recordingStateSubject.send(.idle)
        _recordButtonImageNameSubject.send("recording")
        _showToastSubject.send((message: "Ready", duration: 1.5))
        
        cameraService.configureSession()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?._recordingStateSubject.send(.error("Camera Setup Failed: \(error.localizedDescription)"))
                    self?._showToastSubject.send((message: "Error setting up camera: \(error.localizedDescription)", duration: 3.0))
                }
            }, receiveValue: { [weak self] layers in
                self?.frontPreviewLayer = layers.frontLayer
                self?.backPreviewLayer = layers.backLayer
                self?.cameraService.startSession()
            })
            .store(in: &cancellables)
    }
    
    func setupPreviewLayersInViews(frontView: UIView, backView: UIView) {
        guard let frontLayer = self.frontPreviewLayer, let backLayer = self.backPreviewLayer else { return }
        
        frontLayer.frame = frontView.bounds
        frontView.layer.addSublayer(frontLayer)
        
        backLayer.frame = backView.bounds
        backView.layer.addSublayer(backLayer)
    }

    func viewDidLayoutSubviews() {
         DispatchQueue.main.async {
            self.frontPreviewLayer?.frame = self.frontPreviewLayer?.superlayer?.bounds ?? .zero
            self.backPreviewLayer?.frame = self.backPreviewLayer?.superlayer?.bounds ?? .zero
        }
    }

    private func subscribeToCameraOutput() {
        cameraService.cameraOutputPublisher
            .sink { [weak self] cameraOutput in
                self?.handleSampleBuffer(cameraOutput.sampleBuffer, type: cameraOutput.type)
            }
            .store(in: &cancellables)
    }

    func toggleRecording() {
        switch _recordingStateSubject.value {
        case .idle, .error:
            initiateStartRecording()
        case .recording:
            initiateStopRecording(reason: "User action")
        case .starting, .stopping, .saving:
            _showToastSubject.send((message: "Busy...", duration: 1.0))
            break
        }
    }

    private func initiateStartRecording() {
        _recordingStateSubject.send(.starting)
        _recordButtonImageNameSubject.send("stop")
        _showToastSubject.send((message: "Starting...", duration: 1.0))
        _recordingProgressSubject.send(0.0)

        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "dualVideo_\(timestamp).mov"
        self.outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: self.outputURL)

        do {
            assetWriter = try AVAssetWriter(outputURL: self.outputURL, fileType: .mov)
            let videoSize = CGSize(width: 720, height: 1280)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoSize.width,
                AVVideoHeightKey: videoSize.height
            ]
            writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput?.expectsMediaDataInRealTime = true

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                // CHANGE: kCO... -> kCV...
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height,
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

            if assetWriter!.canAdd(writerInput!) { assetWriter!.add(writerInput!) }

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44100.0, AVEncoderBitRateKey: 64000
            ]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            if assetWriter!.canAdd(audioInput!) { assetWriter!.add(audioInput!) }

            assetWriter?.startWriting()
            _recordingStateSubject.send(.recording)
            currentRecordingStartTime = nil

            DispatchQueue.main.async {
                self.recordingTimer?.invalidate()
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: self.recordingDuration, repeats: false) { [weak self] _ in
                    self?.initiateStopRecording(reason: "Timer ended")
                }
            }

        } catch {
            _recordingStateSubject.send(.error("Failed to start recording: \(error.localizedDescription)"))
            _showToastSubject.send((message: "Error starting recording", duration: 2.5))
            _recordButtonImageNameSubject.send("recording")
            resetRecordingInternals()
        }
    }

    private func initiateStopRecording(reason: String) {
        guard _recordingStateSubject.value == .recording || _recordingStateSubject.value == .starting else {
            if _recordingStateSubject.value == .starting {
                 _showToastSubject.send((message: "Recording cancelled", duration: 1.5))
                 resetRecordingInternals()
                 _recordingStateSubject.send(.idle)
                 _recordButtonImageNameSubject.send("recording")
                 _recordingProgressSubject.send(0.0)
                 DispatchQueue.main.async { self.recordingTimer?.invalidate() }
            }
            return
        }

        _recordingStateSubject.send(.stopping)
        _recordButtonImageNameSubject.send("recording")
        _recordingProgressSubject.send(0.0)
        _showToastSubject.send((message: reason == "Timer ended" ? "Time up! Saving..." : "Stopping...", duration: 1.0))
        
        DispatchQueue.main.async {
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
        }

        writerInput?.markAsFinished()
        audioInput?.markAsFinished()

        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self._recordingStateSubject.send(.saving)
                self._showToastSubject.send((message: "Saving...", duration: 1.0))
                self.saveVideoFile()
            }
        }
    }

    private func saveVideoFile() {
        guard let url = self.outputURL else {
            _recordingStateSubject.send(.error("No video URL to save."))
            _showToastSubject.send((message: "Save failed: No output URL", duration: 2.5))
            resetRecordingInternals()
            return
        }

        photoLibraryService.saveVideoToAlbum(url: url, albumName: self.albumName) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self._showToastSubject.send((message: "Video saved to '\(self.albumName)'!", duration: 2.0))
                    self._navigateToTabSubject.send(2)
                    self._recordingStateSubject.send(.idle)
                case .failure(let error):
                    self._recordingStateSubject.send(.error("Save failed: \(error.localizedDescription)"))
                    self._showToastSubject.send((message: "Save failed: \(error.localizedDescription)", duration: 3.0))
                }
                self.resetRecordingInternals()
            }
        }
    }
    
    private func resetRecordingInternals() {
        assetWriter = nil
        writerInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        currentRecordingStartTime = nil
        // CHANGE: Explicitly type nil assignment
        frontBuffer = nil as CVPixelBuffer?
        backBuffer = nil as CVPixelBuffer?
    }

    private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, type: CameraOutput.OutputType) {
        guard case .recording = _recordingStateSubject.value, let writer = assetWriter else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if currentRecordingStartTime == nil {
            writer.startSession(atSourceTime: timestamp)
            currentRecordingStartTime = timestamp
        }

        switch type {
        case .videoFront:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            if let bgraBuffer = videoProcessingService.convertTo32BGRA(pixelBuffer: pixelBuffer) {
                frontBuffer = bgraBuffer
                processCombinedVideoFrame(timestamp: timestamp)
            }
        case .videoBack:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
             if let bgraBuffer = videoProcessingService.convertTo32BGRA(pixelBuffer: pixelBuffer) {
                backBuffer = bgraBuffer
                processCombinedVideoFrame(timestamp: timestamp)
            }
        case .audio:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        }
    }

    private func processCombinedVideoFrame(timestamp: CMTime) {
        guard let currentFrontBuffer = frontBuffer,
              let currentBackBuffer = backBuffer,
              let pAdaptor = pixelBufferAdaptor,
              let vInput = writerInput, vInput.isReadyForMoreMediaData else {
            return
        }

        if let combinedBuffer = videoProcessingService.createCombinedPixelBuffer(topBuffer: currentFrontBuffer, bottomBuffer: currentBackBuffer) {
            pAdaptor.append(combinedBuffer, withPresentationTime: timestamp)
        }
        
        // CHANGE: Explicitly type nil assignment
        self.frontBuffer = nil as CVPixelBuffer?
        self.backBuffer = nil as CVPixelBuffer?
    }
}
