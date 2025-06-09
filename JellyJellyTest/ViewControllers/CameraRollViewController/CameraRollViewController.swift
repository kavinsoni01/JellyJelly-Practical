//
//  CameraRollViewController.swift
//  JellyJellyTest
//
//  Created by Kinion's Macbook on 08/06/25.
//
//  Displays videos from the app-specific "Jelly Jelly Videos" album in the Photo Library.
//  Allows users to view and delete these videos.
//

import UIKit
import Photos // For PHPhotoLibrary, PHAsset, etc.
import AVKit  // For AVPlayerViewController

class CameraRollViewController: UIViewController, CameraRollCellDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var collectionCameraRoll: UICollectionView!
    
    // MARK: - Private Properties
    /// Array of `PHAsset` objects representing the videos to be displayed.
    private var videoAssets: [PHAsset] = []
    
    /// `PHCachingImageManager` for efficiently loading video thumbnails.
    private let imageManager = PHCachingImageManager()
    
    /// The target size for thumbnail images, adjusted for screen scale.
    private var thumbnailSize: CGSize = .zero
    
    /// The name of the custom album in the Photo Library where app videos are stored/read from.
    private let jellyAlbumName = "Jelly Jelly Videos" // Defined as a constant for clarity

    /// Placeholder view displayed when no videos are found or permissions are denied.
    private var noVideosPlaceholderView: UIView!

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        setupNoVideosPlaceholderView() // Setup placeholder before collection view
        setupCollectionView()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkPhotoLibraryPermission() // Permissions check will trigger data loading
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update placeholder view frame if it's manually laid out (though Auto Layout is preferred).
        // noVideosPlaceholderView.frame = view.bounds // If using manual frame

        // Adjust collection view item sizes if the view's bounds have changed (e.g., rotation).
        updateCollectionViewLayoutItemSize()
    }
    
    // MARK: - Setup Methods
    
    /// Configures the navigation bar appearance for this view controller.
    private func configureNavigationBar() {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.title = "Camera Roll"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
    
    /// Sets up the placeholder view that is shown when there are no videos.
    private func setupNoVideosPlaceholderView() {
        noVideosPlaceholderView = UIView()
        noVideosPlaceholderView.backgroundColor = .systemBackground
        noVideosPlaceholderView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        noVideosPlaceholderView.addSubview(stackView)

        let imageView = UIImageView()
        imageView.image = UIImage(named: "no-video") // Ensure this asset exists
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 120)
        ])
        
        let label = UILabel()
        label.text = "You have no videos in Jelly Jelly.\nYou can create a new one!"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(label)

        // Add placeholder to the main view, initially hidden and behind the collection view.
        view.insertSubview(noVideosPlaceholderView, belowSubview: collectionCameraRoll)
        
        // Constrain placeholder to cover the same area as the collection view.
        NSLayoutConstraint.activate([
            noVideosPlaceholderView.leadingAnchor.constraint(equalTo: collectionCameraRoll.leadingAnchor),
            noVideosPlaceholderView.trailingAnchor.constraint(equalTo: collectionCameraRoll.trailingAnchor),
            noVideosPlaceholderView.topAnchor.constraint(equalTo: collectionCameraRoll.topAnchor),
            noVideosPlaceholderView.bottomAnchor.constraint(equalTo: collectionCameraRoll.bottomAnchor),
            
            stackView.centerXAnchor.constraint(equalTo: noVideosPlaceholderView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: noVideosPlaceholderView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: noVideosPlaceholderView.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: noVideosPlaceholderView.trailingAnchor, constant: -30)
        ])
        
        noVideosPlaceholderView.isHidden = true // Initially hidden
    }

    /// Updates the visibility of the placeholder view and collection view based on `videoAssets`.
    private func updatePlaceholderVisibility() {
        DispatchQueue.main.async { // Ensure UI updates are on the main thread
            let hasVideos = !self.videoAssets.isEmpty
            self.noVideosPlaceholderView.isHidden = hasVideos
            self.collectionCameraRoll.isHidden = !hasVideos

            if !hasVideos {
                self.view.bringSubviewToFront(self.noVideosPlaceholderView)
            }
            // No need to bring collectionCameraRoll to front if placeholder is hidden,
            // as it's already above it in the view hierarchy.
        }
    }

    /// Configures the collection view, its layout, and registers cell nibs.
    private func setupCollectionView() {
        collectionCameraRoll.delegate = self
        collectionCameraRoll.dataSource = self
        
        let nib = UINib(nibName: CameraRollCell.identifier, bundle: nil)
        collectionCameraRoll.register(nib, forCellWithReuseIdentifier: CameraRollCell.identifier)
        
        // Adjust content inset behavior, useful if under a translucent navigation bar.
        if #available(iOS 11.0, *) {
            self.collectionCameraRoll.contentInsetAdjustmentBehavior = .automatic
        }
        self.collectionCameraRoll.showsHorizontalScrollIndicator = false
        self.collectionCameraRoll.backgroundColor = .systemBackground // Match placeholder background
            
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        // Item size calculation will be done in `updateCollectionViewLayoutItemSize`
        // and called from `viewDidLoad` (for initial setup) and `viewDidLayoutSubviews` (for updates).
        self.collectionCameraRoll.collectionViewLayout = layout
        updateCollectionViewLayoutItemSize() // Perform initial layout calculation
    }

    /// Calculates and applies the item size for the collection view layout.
    /// Call this when the view loads and when its layout changes (e.g., rotation).
    private func updateCollectionViewLayoutItemSize() {
        
        DispatchQueue.main.async {
            
            
            guard let layout = self.collectionCameraRoll.collectionViewLayout as? UICollectionViewFlowLayout else { return }
            
            let spacing: CGFloat = 10 // Spacing between items and section insets
            // Use view.bounds.width for reliable width, collectionCameraRoll.bounds might not be final.
            let collectionViewWidth = self.collectionCameraRoll.frame.width - (self.collectionCameraRoll.contentInset.left + self.collectionCameraRoll.contentInset.right)
            
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            let columns: CGFloat = isPad ? 4 : 2 // Number of columns based on device type
            
            layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing) // Consistent spacing
            layout.minimumLineSpacing = spacing
            layout.minimumInteritemSpacing = spacing
            
            // Calculate available width for cells
            let availableWidth = collectionViewWidth - (layout.sectionInset.left + layout.sectionInset.right + (spacing * (columns - 1)))
            let cellWidth = floor(availableWidth / columns)
            // Maintain an aspect ratio for cell height, e.g., 4:3 or 16:9. Here, 1.35 implies roughly 3:4 portrait.
            let cellHeight: CGFloat = cellWidth * 1.35
            
            // Update layout if item size needs to change
            if layout.itemSize.width != cellWidth || layout.itemSize.height != cellHeight {
                layout.itemSize = CGSize(width: cellWidth, height: cellHeight)
                // `invalidateLayout()` is not strictly needed here if only itemSize changes and is applied directly,
                // but good practice if other layout attributes might depend on it.
                // layout.invalidateLayout()
            }
            
            // Update thumbnailSize for fetching appropriately scaled images
            let scale = UIScreen.main.scale
            self.thumbnailSize = CGSize(width: cellWidth * scale, height: cellHeight * scale)
        }
    }

    // MARK: - Photo Library Access & Data Loading
    /// Checks Photo Library permissions and proceeds to load videos or show an alert.
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            loadVideosFromJellyAlbum()
        case .denied, .restricted:
            showPermissionAlert()
            updatePlaceholderVisibility() // Show placeholder if access denied
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.loadVideosFromJellyAlbum()
                    } else {
                        self?.showPermissionAlert()
                        self?.updatePlaceholderVisibility() // Show placeholder if access denied post-request
                    }
                }
            }
        @unknown default:
            print(" Unknown PHPhotoLibrary authorization status.")
            updatePlaceholderVisibility() // Default to showing placeholder
        }
    }

    /// Displays an alert guiding the user to grant Photo Library permission in Settings.
    private func showPermissionAlert() {
        let alert = UIAlertController(title: "Permission Denied", message: "Please grant Photo Library access in Settings to view videos.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    /// Fetches videos from the app-specific album in the Photo Library.
    private func loadVideosFromJellyAlbum() {
        fetchAlbum(named: jellyAlbumName) { [weak self] album in
            guard let self = self else { return }
            
            var fetchedAssets: [PHAsset] = []
            if let album = album {
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] // Show newest first
                
                let assetsFetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
                assetsFetchResult.enumerateObjects { (asset, _, _) in
                    fetchedAssets.append(asset)
                }
            }
            
            self.videoAssets = fetchedAssets
            
            // Update UI on the main thread
            DispatchQueue.main.async {
                self.collectionCameraRoll.reloadData()
                self.updatePlaceholderVisibility()
                if self.videoAssets.isEmpty {
                    print(" No videos found in '\(self.jellyAlbumName)' album or album does not exist.")
                }
            }
        }
    }

    /// Helper to fetch a specific `PHAssetCollection` (album) by its name.
    /// - Parameters:
    ///   - albumName: The title of the album to fetch.
    ///   - completion: A closure called with the fetched `PHAssetCollection` or `nil` if not found.
    private func fetchAlbum(named albumName: String, completion: @escaping (PHAssetCollection?) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        completion(collections.firstObject) // Return the first match, or nil
    }
    
    // MARK: - Video Deletion
    /// Handles the deletion of a video asset from the Photo Library.
    /// - Parameters:
    ///   - asset: The `PHAsset` to delete.
    ///   - indexPath: The `IndexPath` of the item in the collection view representing this asset.
    private func deleteVideoAsset(_ asset: PHAsset, at indexPath: IndexPath) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    print(" Video deleted successfully.")
                    self.videoAssets.remove(at: indexPath.item)
                    // Perform batch updates for smoother UI update
                    self.collectionCameraRoll.performBatchUpdates({
                        self.collectionCameraRoll.deleteItems(at: [indexPath])
                    }, completion: { _ in
                        self.updatePlaceholderVisibility() // Update placeholder if all videos are deleted
                    })
                } else {
                    print(" Error deleting video: \(error?.localizedDescription ?? "Unknown error")")
                    let errorAlert = UIAlertController(title: "Error", message: "Could not delete the video. Please try again.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(errorAlert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Video Playback
    /// Initiates playback of the selected video asset.
    /// - Parameter asset: The `PHAsset` to play.
    private func playVideo(asset: PHAsset) {
        guard asset.mediaType == .video else {
            print(" Selected asset is not a video.")
            return
        }

        let videoRequestOptions = PHVideoRequestOptions()
        videoRequestOptions.isNetworkAccessAllowed = true // Allow streaming from iCloud
        videoRequestOptions.deliveryMode = .automatic    // Balances quality and speed

        PHImageManager.default().requestPlayerItem(forVideo: asset, options: videoRequestOptions) { [weak self] (playerItem, info) in
            DispatchQueue.main.async {
                guard let self = self, let playerItem = playerItem else {
                    print(" Could not retrieve player item for video.")
                    let errorAlert = UIAlertController(title: "Playback Error", message: "Could not prepare this video for playback.", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(errorAlert, animated: true)
                    return
                }

                let player = AVPlayer(playerItem: playerItem)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                
                // Present the player. Ensure it's presented from the correct context.
                let presentingVC = self.navigationController ?? self
                presentingVC.present(playerViewController, animated: true) {
                    playerViewController.player?.play() // Start playback once presented
                }
            }
        }
    }
}

// MARK: - UICollectionViewDataSource
extension CameraRollViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1 // Single section for videos
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CameraRollCell.identifier, for: indexPath) as? CameraRollCell else {
            fatalError("Unable to dequeue CameraRollCell. Check identifier and cell registration.")
        }
        
        let asset = videoAssets[indexPath.item]
        // Configure cell with asset and pre-calculated thumbnail size for efficient image loading
        cell.configure(with: asset, imageManager: imageManager, targetSize: self.thumbnailSize)
        cell.delegate = self // Set delegate for delete action
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension CameraRollViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = videoAssets[indexPath.item]
        playVideo(asset: asset)
    }
}

// MARK: - CameraRollCellDelegate
extension CameraRollViewController /* : CameraRollCellDelegate */ { // Already conformed at class declaration
    func cameraRollCellDidTapDelete(_ cell: CameraRollCell) {
        guard let indexPath = collectionCameraRoll.indexPath(for: cell) else { return }
        let assetToDelete = videoAssets[indexPath.item]

        // Confirm deletion with the user
        let alert = UIAlertController(title: "Delete Video", message: "Are you sure you want to delete this video from your Photo Library?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.deleteVideoAsset(assetToDelete, at: indexPath)
        }))
        present(alert, animated: true)
    }
}
