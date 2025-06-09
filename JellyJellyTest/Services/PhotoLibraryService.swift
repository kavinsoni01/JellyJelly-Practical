import Foundation
import Photos

// MARK: - PhotoLibraryServiceProtocol
/// Defines the contract for a service that interacts with the Photo Library,
/// specifically for saving video assets.
protocol PhotoLibraryServiceProtocol {
    /// Saves a video from a given URL to a specified album in the Photo Library.
    /// - Parameters:
    ///   - url: The `URL` of the video file to save.
    ///   - albumName: The name of the album to save the video into. If the album doesn't exist, it will be created.
    ///   - completion: A closure called with the `Result` of the operation, indicating success (`Void`) or an `Error`.
    func saveVideoToAlbum(url: URL, albumName: String, completion: @escaping (Result<Void, Error>) -> Void)
}

// MARK: - PhotoLibraryService
/// Concrete implementation of `PhotoLibraryServiceProtocol`.
class PhotoLibraryService: PhotoLibraryServiceProtocol {

    // MARK: - PhotoLibraryError
    /// Custom error types specific to Photo Library operations.
    enum PhotoLibraryError: LocalizedError {
        case permissionDenied
        case couldNotFindOrCreateAlbum
        case assetCreationFailure(Error?) // Includes an optional underlying system error.
        case generalError(Error)        // Wraps other unexpected errors.

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Photo Library permission was denied. Please grant access in Settings."
            case .couldNotFindOrCreateAlbum:
                return "Could not create or find the specified album in the Photo Library."
            case .assetCreationFailure(let underlyingError):
                var message = "Failed to save video asset to the Photo Library"
                if let error = underlyingError {
                    message += ": \(error.localizedDescription)"
                } else {
                    message += "."
                }
                return message
            case .generalError(let underlyingError):
                return "An unexpected error occurred with the Photo Library: \(underlyingError.localizedDescription)"
            }
        }
    }

    // MARK: - PhotoLibraryServiceProtocol Implementation
    func saveVideoToAlbum(url: URL, albumName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Request authorization to add photos/videos.
        // `.addOnly` is appropriate if the app only needs to save new items.
        // Use `.readWrite` if it also needs to fetch/modify existing library content through this service.
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            // Ensure subsequent operations and completion handler are on the main thread if they involve UI.
            // For safety, critical PHPhotoLibrary changes are often dispatched to main.
            DispatchQueue.main.async {
                guard status == .authorized else {
                    completion(.failure(PhotoLibraryError.permissionDenied))
                    return
                }

                // Proceed to fetch or create the album.
                self.fetchOrCreateAlbum(named: albumName) { result in
                    switch result {
                    case .success(let album):
                        // Perform changes to the Photo Library (saving the asset).
                        PHPhotoLibrary.shared().performChanges({
                            // Create a request to add the video file as an asset.
                            guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) else {
                                // This situation is unlikely if the URL is valid but good to be aware of.
                                // The error will be caught by the outer completion's error parameter.
                                print("Failed to create asset request for URL: \(url)")
                                return
                            }
                            
                            // Get placeholder for the newly created asset.
                            guard let assetPlaceholder = assetRequest.placeholderForCreatedAsset,
                                  // Create a request to change the album (add the new asset).
                                  let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                                print("Could not get asset placeholder or album change request.")
                                return
                            }
                            // Add the new asset to the album.
                            let assets: NSArray = [assetPlaceholder] as NSArray
                            albumChangeRequest.addAssets(assets)
                        }) { success, error in
                            // Handle the result of the performChanges operation.
                            DispatchQueue.main.async { // Ensure completion is on main thread
                                if success {
                                    completion(.success(()))
                                } else {
                                    // If an error occurred, wrap it in our custom error type.
                                    completion(.failure(PhotoLibraryError.assetCreationFailure(error)))
                                }
                            }
                        }
                    case .failure(let error):
                        // Propagate error from album fetching/creation.
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers
    /// Fetches an existing album by name or creates it if it doesn't exist.
    /// - Parameters:
    ///   - albumName: The name of the album to fetch or create.
    ///   - completion: A closure called with the `Result`, containing the `PHAssetCollection` or an `Error`.
    private func fetchOrCreateAlbum(named albumName: String, completion: @escaping (Result<PHAssetCollection, Error>) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        // If the album already exists, return it.
        if let album = collections.firstObject {
            completion(.success(album))
        } else {
            // Album doesn't exist, so create it.
            var albumPlaceholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }) { success, error in
                DispatchQueue.main.async { // Ensure completion is on main thread
                    if success, let placeholder = albumPlaceholder {
                        // Fetch the newly created album using its placeholder.
                        let newCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                        if let newAlbum = newCollections.firstObject {
                            completion(.success(newAlbum))
                        } else {
                            // Should not happen if placeholder was valid, but handle defensively.
                            completion(.failure(PhotoLibraryError.couldNotFindOrCreateAlbum))
                        }
                    } else {
                        // Failed to create the album.
                        completion(.failure(PhotoLibraryError.assetCreationFailure(error))) // Reusing error type
                    }
                }
            }
        }
    }
}
