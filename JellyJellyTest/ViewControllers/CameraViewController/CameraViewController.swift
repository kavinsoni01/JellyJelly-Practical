import UIKit
import AVFoundation // Keep for AVCaptureVideoPreviewLayer if needed, but VM provides it
import Combine

class CameraViewController: UIViewController {
    
    @IBOutlet weak var backCameraPreview: UIView!
    @IBOutlet weak var frontCameraPreview: UIView!
    // recordButton will be configured in setupUI and used directly from there.
    private let recordButton = AnimatedRecordButton()

    private var viewModel: CameraViewModelProtocol! // To be injected or instantiated
    private var cancellables = Set<AnyCancellable>()


    override func viewDidLoad() {
        super.viewDidLoad()

        // Instantiate ViewModel (In a real app, use dependency injection)
        let cameraService = CameraService()
        let videoProcessingService = VideoProcessingService()
        let photoLibraryService = PhotoLibraryService()
        viewModel = CameraViewModel(
            cameraService: cameraService,
            videoProcessingService: videoProcessingService,
            photoLibraryService: photoLibraryService
        )

        setupUI()
        bindViewModel()
        viewModel.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Inform ViewModel that layout happened so it can adjust preview layers if needed
        // The ViewModel's preview layers should resize with their superviews (frontCameraPreview, backCameraPreview)
        // This call ensures the ViewModel can update its layer's frame if it's managing it directly.
        viewModel.setupPreviewLayersInViews(frontView: frontCameraPreview, backView: backCameraPreview)
        // viewModel.viewDidLayoutSubviews()
    }

    private func setupUI() {
        
        // Ensure preview views are prepared for layers
        frontCameraPreview.layer.masksToBounds = true
        backCameraPreview.layer.masksToBounds = true

        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        view.addSubview(recordButton)
        
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70)
        ])
    }

    private func bindViewModel() {
        viewModel.recordingStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                // self?.recordButton.isEnabled = true // Generally enable, VM state handles specifics
                switch state {
                case .idle, .error:
                    self?.recordButton.resetProgress()
                    // Potentially update button image if not handled by imageNamePublisher
                case .starting:
                     self?.recordButton.animateProgress(to: 1.0, duration: 15.0) // Or listen to progress publisher
                case .recording:
                    // Progress animation might be ongoing or handled by separate publisher
                    break
                case .stopping, .saving:
                    self?.recordButton.resetProgress()
                }
            }
            .store(in: &cancellables)

        viewModel.recordButtonImageNamePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] imageName in
                self?.recordButton.setCenterImage(UIImage(named: imageName))
            }
            .store(in: &cancellables)

        viewModel.showToastPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] toastInfo in
                self?.showToast(message: toastInfo.message, duration: toastInfo.duration)
            }
            .store(in: &cancellables)

        viewModel.navigateToTabPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tabIndex in
                self?.tabBarController?.selectedIndex = tabIndex
            }
            .store(in: &cancellables)
        
        // ViewModel will inform when layers are ready, then VC adds them
        // This is handled by viewModel.viewDidLoad() -> cameraService.configureSession()
        // and then the VC calls setupPreviewLayersInViews via viewDidLayoutSubviews or a dedicated publisher if preferred.
        // For simplicity, we ensure layers are added once the views are laid out.
    }

    @objc private func recordButtonTapped() {
        viewModel.toggleRecording()
    }

    private func showToast(message: String, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
        // ... (Your existing showToast implementation)
        DispatchQueue.main.async {
            // Remove any existing toast
            self.view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

            let toastContainer = UIView()
            toastContainer.tag = 999 // Tag to find and remove existing toasts
            toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            toastContainer.alpha = 0.0
            toastContainer.layer.cornerRadius = 10
            toastContainer.clipsToBounds  =  true
            toastContainer.translatesAutoresizingMaskIntoConstraints = false
            
            let toastLabel = UILabel()
            toastLabel.textColor = UIColor.white
            toastLabel.font = UIFont.systemFont(ofSize: 15.0)
            toastLabel.textAlignment = .center
            toastLabel.text = message
            toastLabel.numberOfLines = 0
            toastLabel.translatesAutoresizingMaskIntoConstraints = false
            
            toastContainer.addSubview(toastLabel)
            self.view.addSubview(toastContainer)
            
            NSLayoutConstraint.activate([
                toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 15),
                toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -15),
                toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 10),
                toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -10),
                
                toastContainer.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                toastContainer.bottomAnchor.constraint(equalTo: self.recordButton.topAnchor, constant: -20), // Position above record button
                toastContainer.widthAnchor.constraint(lessThanOrEqualTo: self.view.widthAnchor, multiplier: 0.85),
                toastContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 35)
            ])
            
            UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseIn, animations: {
                toastContainer.alpha = 1.0
            }, completion: { _ in
                UIView.animate(withDuration: 0.4, delay: duration, options: .curveEaseOut, animations: {
                    toastContainer.alpha = 0.0
                }, completion: {(_: Bool) in
                    toastContainer.removeFromSuperview()
                    completion?()
                })
            })
        }
    }
}
