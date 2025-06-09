//
//  FeedViewController.swift
//  JellyJellyTest
//
//  Created by Kavin's Macbook on 06/06/25.
//

import UIKit

class FeedViewController: BaseViewController, FeedViewModelProtocol, UICollectionViewDelegate, UICollectionViewDataSource, FeedCollectionCellDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Properties
    private var viewModel: FeedViewModel!

    /// Flag to manage initial setup logic in `viewDidAppear`.
    private var isFirstAppearance = true
    /// Flag to track if `viewDidAppear` has been called, to prevent auto-scrolling before view is fully visible.
    private var hasViewAppeared = false

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        setupCollectionView()
        setupPullToRefresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reset flag for logic that should run once per appearance, like initial scrolling.
        isFirstAppearance = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasViewAppeared = true
        // On first appearance after data load, scroll to the first video and start playback.
        if isFirstAppearance, let count = viewModel.arrVideoList?.count, count > 0 {
            scrollAndAutoPlay(to: 0)
            isFirstAppearance = false // Prevent this from running again until next full appearance cycle
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hasViewAppeared = false
        // Pause all currently visible video cells to conserve resources when the view is not active.
        for cell in collectionView.visibleCells {
            if let videoCell = cell as? FeedCollectionCell {
                videoCell.pause()
            }
        }
        // Optionally, reset the current playing index if desired when view disappears.
        viewModel.currentPlayingIndex = nil 
    }

    // MARK: - Setup Methods
    private func setupViewModel() {
        self.viewModel = FeedViewModel(delegate: self)
        // Initial fetch of video data
        self.viewModel.callExporeVideoListAPI()
    }

    private func setupCollectionView() {
        // Configure the layout for a full-screen, vertically paging collection view.
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0 // No space between cells
        // Item size will be set in viewDidLayoutSubviews to ensure correct bounds are used.
        // For viewDidLoad, it can be an initial estimate if necessary.
        layout.itemSize = CGSize(width: self.view.bounds.width, height: self.view.bounds.height) 
        layout.sectionInset = .zero // No insets around the section
        
        self.collectionView.collectionViewLayout = layout
        self.collectionView.isPagingEnabled = true // Snap to full cells
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.register(UINib(nibName: "FeedCollectionCell", bundle: nil), forCellWithReuseIdentifier: "FeedCollectionCell")
        self.collectionView.backgroundColor = .black // Background for the feed area
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false // If using Auto Layout from code, not Storyboard constraints
    }

    private func setupPullToRefresh() {
        viewModel.setupRefreshControl(for: collectionView, target: self, action: #selector(handlePullToRefresh))
    }

    // MARK: - Actions
    @objc private func handlePullToRefresh() {
        viewModel.callExporeVideoListAPI(isPullToRefresh: true)
    }

    // MARK: - Layout & Display Logic
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure collection view item size is updated if the view's bounds change (e.g., rotation).
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            if layout.itemSize.width != collectionView.bounds.width || layout.itemSize.height != collectionView.bounds.height {
                layout.itemSize = CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
                layout.invalidateLayout() // Apply the new size
            }
        }
    }

    /// Scrolls the collection view to the specified index and attempts to play the video.
    /// - Parameter index: The index of the video item to scroll to.
    private func scrollAndAutoPlay(to index: Int) {
        guard hasViewAppeared, // Only scroll if view is actually visible
              index >= 0, index < (viewModel.arrVideoList?.count ?? 0) else { return }
              
        let indexPath = IndexPath(item: index, section: 0)
        
        // Ensure layout is complete before scrolling to avoid animation glitches or incorrect positioning.
        collectionView.layoutIfNeeded() 
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        // Playback and profile fetching for the target cell will be handled by scrollViewDidEndDecelerating
        // or explicitly in cellForItemAt if it's the initial setup.
        // We can also update the currentPlayingIndex here to be more proactive.
        viewModel.setCurrentPlayingIndex(index) // This will trigger profile fetch and tell cell to play if it's the current one.
    }

    /// Reloads the collection view data and handles scrolling to the initial video.
    private func reloadVideos() {
        collectionView.reloadData()
        // After reloading, ensure the UI is updated correctly, especially for the first video.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in // Short delay for reloadData to settle
            guard let self = self else { return }
            if let videos = self.viewModel.arrVideoList, !videos.isEmpty {
                // If no video is currently marked as playing (e.g., after a fresh load),
                // set the first video as current, which will trigger its profile fetch and playback.
                if self.viewModel.currentPlayingIndex == nil {
                    self.scrollAndAutoPlay(to: 0) // Scroll to first item
                    self.viewModel.setCurrentPlayingIndex(0) // Explicitly set and trigger logic for first item
                } else if let currentIndex = self.viewModel.currentPlayingIndex, currentIndex < videos.count {
                    // If there was a current index, re-scroll to it to ensure correct state.
                    self.scrollAndAutoPlay(to: currentIndex)
                } else {
                    // Fallback if current index is invalid, scroll to 0.
                    self.scrollAndAutoPlay(to: 0)
                    self.viewModel.setCurrentPlayingIndex(0)
                }
            }
        }
    }

    // MARK: - FeedViewModelProtocol
    func getVideoListFail(withMessage message: String) {
        print("Failed to get video list: \(message)")
    }
    
    func getVideoListSuccess() {
        DispatchQueue.main.async {
            self.reloadVideos()
        }
    }

    func didFetchUserProfile(_ profile: UserModel, forVideoAtIndex index: Int) {
        print("Profile fetched for index \(index): \(profile)")
        guard index < (viewModel.arrVideoList?.count ?? 0),
              let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? FeedCollectionCell else {
            print("Cell not found or index out of bounds for profile update at index \(index)")
            return
        }
        print("Updating cell at index \(index) with profile.")
        cell.updateUserInfo(with: profile)
    }

    func didFailToFetchUserProfile(error: Error, forVideoAtIndex index: Int) {
        print("Failed to fetch user profile for video at index \(index): \(error.localizedDescription)")
         guard index < (viewModel.arrVideoList?.count ?? 0),
               let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? FeedCollectionCell else {
             print("Cell not found or index out of bounds for profile error update at index \(index)")
             return
         }
         cell.resetUserInfo() 
    }

    // MARK: - UICollectionViewDataSource, UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.arrVideoList?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCollectionCell", for: indexPath) as! FeedCollectionCell
        cell.delegate = self
        if let video = viewModel.arrVideoList?[indexPath.item] {
            cell.configure(with: video) 
            
            print("--- Configuring cell for video at index: \(indexPath.item), Video ID: \(video.id ?? "N/A"), User ID: \(video.userId ?? "N/A")")
            
            if let ownerId = video.userId {
                if let cachedProfile = viewModel.userProfileCache[ownerId] {
                    print("Cache hit for ownerId \(ownerId) at index \(indexPath.item). Updating cell with cached profile.")
                    cell.updateUserInfo(with: cachedProfile)
                } else {
                    print("Cache miss for ownerId \(ownerId) at index \(indexPath.item). Resetting user info and requesting profile.")
                    cell.resetUserInfo() 
                    viewModel.requestUserProfileIfNeeded(for: video, at: indexPath.item)
                }
            } else {
                print("User ID is nil for video at index \(indexPath.item). Resetting user info.")
                cell.resetUserInfo()
            }
            
            if viewModel.currentPlayingIndex == indexPath.item {
                print("Playing video at index \(indexPath.item) as it's the current playing index.")
                cell.play()
            } else {
                cell.pause()
            }
        }
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        if let indexPath = collectionView.indexPathForItem(at: visiblePoint) {
            print("ScrollView did end decelerating. New current index: \(indexPath.row)")
            viewModel.setCurrentPlayingIndex(indexPath.row) 
            
            for cell in collectionView.visibleCells {
                if let videoCell = cell as? FeedCollectionCell,
                   let cellIndexPath = collectionView.indexPath(for: videoCell) {
                    if cellIndexPath == indexPath {
                        videoCell.play()
                    } else {
                        videoCell.pause()
                    }
                }
            }
        }
    }

    // MARK: - FeedCollectionCellDelegate
    func didFinishPlayback(cell: FeedCollectionCell) {
        if let indexPath = collectionView.indexPath(for: cell) {
            playNextVideo(after: indexPath.item)
        }
    }
    
    func feedCollectionCell(_ cell: FeedCollectionCell, didTapShareForVideo video: JellyVideo) {
        guard let videoURLString = video.content?.url, let url = URL(string: videoURLString) else {
            print("Share failed: Video URL is nil or invalid for video ID: \(video.id ?? "N/A")")
            let alert = UIAlertController(title: "Share Error", message: "Could not share this video, URL is missing.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        var itemsToShare: [Any] = [url]
        if let title = video.title, !title.isEmpty {
            itemsToShare.append("\nCheck out this video: \(title)")
        } else {
            itemsToShare.append("\nCheck out this video!")
        }

        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        
        if let popoverController = activityViewController.popoverPresentationController {
            if let shareButton = cell.shareButton { 
                 popoverController.sourceView = shareButton
                 popoverController.sourceRect = shareButton.bounds
            } else {
                 popoverController.sourceView = cell
                 popoverController.sourceRect = cell.bounds
            }
        }
        
        present(activityViewController, animated: true, completion: nil)
    }

    func playNextVideo(after index: Int) {
        let nextIndex = index + 1
        guard let count = viewModel.arrVideoList?.count, nextIndex < count else { return }
        scrollAndAutoPlay(to: nextIndex)
    }
}
