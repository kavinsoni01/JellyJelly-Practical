//
//  FeedViewModel.swift
//  JellyJellyTest
//
//  Created by Kavin's Macbook on 06/06/25.
//
//  Manages the data and business logic for the video feed.
//  It fetches video lists and user profiles, caching profiles for efficiency.
//

import UIKit
import Foundation

// MARK: - FeedViewModelProtocol
/// Defines the communication interface from the FeedViewModel to its View (e.g., FeedViewController).
/// This allows the View to react to data updates and state changes.
protocol FeedViewModelProtocol: AnyObject {
    /// Notifies the delegate that fetching the video list has failed.
    /// - Parameter message: A string describing the error.
    func getVideoListFail(withMessage message: String)
    
    /// Notifies the delegate that the video list has been successfully fetched and updated.
    func getVideoListSuccess()
    
    /// Notifies the delegate that a user profile has been successfully fetched.
    /// - Parameters:
    ///   - profile: The `UserModel` object containing the fetched profile data.
    ///   - index: The index in `arrVideoList` for which this profile was fetched.
    func didFetchUserProfile(_ profile: UserModel, forVideoAtIndex index: Int)
    
    /// Notifies the delegate that fetching a user profile has failed.
    /// - Parameters:
    ///   - error: The `Error` object describing why the fetch failed.
    ///   - index: The index in `arrVideoList` for which the profile fetch was attempted.
    func didFailToFetchUserProfile(error: Error, forVideoAtIndex index: Int)
}

// MARK: - FeedViewModel
/// ViewModel responsible for managing the video feed's data, including fetching videos and user profiles.
class FeedViewModel: NSObject {
    
    // MARK: - Public Properties
    /// The list of videos currently loaded for the feed.
    /// This is typically observed or reloaded by the ViewController when `getVideoListSuccess` is called.
    var arrVideoList: [JellyVideo]?
    
    /// The index of the video currently considered active or playing in the feed.
    var currentPlayingIndex: Int?
    
    // MARK: - Private Properties
    /// The API service responsible for network requests. Conforms to `ApiServiceProtocol` for testability and DIP.
    private var apiService: ApiServiceProtocol
    
    /// A weak reference to the delegate (typically the ViewController) to send updates.
    private weak var delegate: FeedViewModelProtocol?
    
    /// A flag indicating if a data loading operation (e.g., fetching videos) is currently in progress.
    private(set) var isLoading: Bool = false
    
    /// Cache for `UserModel` objects, keyed by user ID, to reduce redundant API calls.
    /// Note: Marked `internal` (default) allowing ViewController to read for initial cell setup for performance.
    /// Strict MVVM might use a ViewModel method to query this.
    var userProfileCache: [String: UserModel] = [:]
    
    /// A set to keep track of user IDs for which a profile fetch is currently in progress.
    /// This helps prevent redundant API calls for the same profile if requested multiple times quickly.
    private var profileFetchInProgress: Set<String> = []

    /// A weak reference to a `UIRefreshControl` managed by the ViewController,
    /// allowing the ViewModel to control its start/stop refreshing animations.
    weak var refreshControl: UIRefreshControl?
    
    // MARK: - Initializer
    /// Initializes the ViewModel with a delegate and an API service.
    /// - Parameters:
    ///   - delegate: The delegate (e.g., `FeedViewController`) to receive updates.
    ///   - apiService: The service used for API calls. Defaults to a new `ApiService` instance.
    init(delegate: FeedViewModelProtocol, apiService: ApiServiceProtocol = ApiService()) {
        self.delegate = delegate
        self.apiService = apiService
    }
    
    // MARK: - Public Methods
    
    /// Updates the `currentPlayingIndex` and triggers a profile fetch for the video at the new index if needed.
    /// - Parameter index: The new index to be set as the current playing index.
    func setCurrentPlayingIndex(_ index: Int) {
        // Ensure index is valid
        guard index >= 0, index < (arrVideoList?.count ?? 0) else {
            // Consider logging an error or handling out-of-bounds appropriately
            return
        }
        
        // Only proceed if the index has actually changed or if it's the first time being set
        if currentPlayingIndex != index || currentPlayingIndex == nil {
            currentPlayingIndex = index
            // If a video exists at this new index, request its owner's profile
            if let video = arrVideoList?[index] {
                requestUserProfileIfNeeded(for: video, at: index)
            }
        }
    }

    /// Requests a user profile if it's not already cached or currently being fetched.
    /// - Parameters:
    ///   - video: The `JellyVideo` for which the owner's profile is needed.
    ///   - index: The index of this video in `arrVideoList`.
    func requestUserProfileIfNeeded(for video: JellyVideo, at index: Int) {
        guard let ownerId = video.userId else {
            // Log or handle cases where ownerId is nil, as profile cannot be fetched.
            return
        }

        // Check cache first
        if let cachedProfile = userProfileCache[ownerId] {
            delegate?.didFetchUserProfile(cachedProfile, forVideoAtIndex: index)
            return
        }

        // Check if a fetch is already in progress for this ownerId
        guard !profileFetchInProgress.contains(ownerId) else {
            // A fetch for this user is already underway.
            return
        }

        // Mark as in progress and initiate API call
        profileFetchInProgress.insert(ownerId)

        apiService.getProfileOfVideoOwner(videoOwnerId: ownerId) { [weak self] result in
            guard let self = self else { return }
            
            // Remove from in-progress set, regardless of success or failure
            self.profileFetchInProgress.remove(ownerId)

            // Dispatch UI updates to the main thread
            DispatchQueue.main.async {
                switch result {
                case .success(let userModelsArray):
                    if let user = userModelsArray.first {
                        self.userProfileCache[ownerId] = user // Cache the fetched profile
                        self.delegate?.didFetchUserProfile(user, forVideoAtIndex: index)
                    } else {
                        // API succeeded but returned no user data for the ID
                        let noUserError = NSError(domain: "FeedViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "No user profile found for ID \(ownerId)"])
                        self.delegate?.didFailToFetchUserProfile(error: noUserError, forVideoAtIndex: index)
                    }
                case .failure(let error):
                    self.delegate?.didFailToFetchUserProfile(error: error, forVideoAtIndex: index)
                }
            }
        }
    }

    /// Fetches the list of videos for the explore feed.
    /// Handles showing a global loader or a pull-to-refresh animation.
    /// - Parameter isPullToRefresh: `true` if triggered by pull-to-refresh, `false` otherwise.
    func callExporeVideoListAPI(isPullToRefresh: Bool = false) {
        isLoading = true
        if !isPullToRefresh {
            Loader.shared.showLoader() // Show global loader
        } else {
            // Start refresh control animation if it's a pull-to-refresh action
            DispatchQueue.main.async { [weak self] in
                self?.refreshControl?.beginRefreshing()
            }
        }
        
        apiService.callExploreVideoList(completion: { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            // Always ensure loaders/refreshers are hidden on completion
            Loader.shared.hideLoader()
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            
            switch result {
            case .success(let response):
                // Ensure the response can be cast to the expected [JellyVideo] type
                if let videos = response as? [JellyVideo] {
                    self.arrVideoList = videos
                    self.userProfileCache.removeAll() // Clear profile cache for the new list
                    self.profileFetchInProgress.removeAll() // Clear in-progress fetches
                    self.currentPlayingIndex = nil // Reset current playing index
                    self.delegate?.getVideoListSuccess()
                } else {
                    // Handle unexpected response type
                    self.delegate?.getVideoListFail(withMessage: "Invalid video data received.")
                }
            case .failure(let error):
                self.delegate?.getVideoListFail(withMessage: error.localizedDescription)
            }
        })
    }
    
    /// Safely retrieves a video at a specific index.
    /// - Parameter index: The index of the video to retrieve.
    /// - Returns: The `JellyVideo` object at the index, or `nil` if the index is out of bounds.
    func videoAt(index: Int) -> JellyVideo? {
        guard let arrVideoList = arrVideoList, index >= 0, index < arrVideoList.count else { return nil }
        return arrVideoList[index]
    }
    
    // MARK: - Pull-to-Refresh Setup
    /// Configures a `UIRefreshControl` for a given `UIScrollView`.
    /// - Parameters:
    ///   - scrollView: The `UIScrollView` (or `UICollectionView`, `UITableView`) to attach the refresh control to.
    ///   - target: The target object that will handle the refresh action.
    ///   - action: The selector to be called when a refresh is triggered.
    func setupRefreshControl(for scrollView: UIScrollView, target: Any, action: Selector) {
        let refresh = UIRefreshControl()
        refresh.tintColor = .black // Customize tint color as needed
        refresh.addTarget(target, action: action, for: .valueChanged)
        scrollView.refreshControl = refresh
        self.refreshControl = refresh // Keep a reference to control it
    }
}
