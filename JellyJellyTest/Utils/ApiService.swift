//
//  ApiService.swift
//  GolfAppDemo // TODO: Consider renaming project/module if this is from a template and not Golf related.
//
//  Created by Kavin's Macbook on 22/05/25.
//
//  Provides specific API endpoints and interactions for the JellyJellyTest application,
//  building upon BaseAPIService for common network request logic.
//

import UIKit
import Network // For NetworkMonitor

// MARK: - ApiServiceProtocol
/// Defines the contract for API services used within the application.
/// This abstraction allows for easier testing and dependency injection.
protocol ApiServiceProtocol: AnyObject {
    /// Fetches the list of videos for the "explore" feed.
    /// - Parameter completion: A closure called with the result, containing either an array of `JellyVideo` objects or an `Error`.
    func callExploreVideoList(completion: @escaping (Result<[JellyVideo], Error>) -> Void)
    
    /// Fetches the profile information for a specific video owner.
    /// - Parameters:
    ///   - videoOwnerId: The unique identifier of the video owner.
    ///   - completion: A closure called with the result, containing either an array of `UserModel` objects (expected to be one) or an `Error`.
    func getProfileOfVideoOwner(videoOwnerId:String, completion: @escaping (Result<[UserModel], Error>) -> Void)
}

// MARK: - ApiService
/// Concrete implementation of `ApiServiceProtocol`.
class ApiService: BaseAPIService, ApiServiceProtocol {
    
    // Default initializer inherits from BaseAPIService.
    // override init() { super.init() } // Not strictly needed if no custom init logic.
    
    // MARK: - EndPoint Enum
    /// Defines specific API endpoints relative to the `baseURL` in `BaseAPIService`.
    private enum EndPoint: String {
        case explore = "shareable_data?select=*&limit=200&privacy=eq.public&order=updated_at.desc"
        case profile = "profiles?select=*" // Base path for profiles; ID and limit are appended.
    }

    // MARK: - ApiServiceProtocol Implementation
    
    func callExploreVideoList(completion: @escaping (Result<[JellyVideo], Error>) -> Void){
        // Construct the full URL for the explore endpoint.
        let urlString = "\(super.endpoint(EndPoint.explore.rawValue))" // `super.endpoint` resolves to BaseAPIService's endpoint method
        
        // Perform the GET request using the generic method from BaseAPIService.
        self.get(url: urlString, responseModelType: [JellyVideo].self, completion: completion)
    }
    
    func getProfileOfVideoOwner(videoOwnerId:String, completion: @escaping (Result<[UserModel], Error>) -> Void){
        // Construct the full URL, appending query parameters for owner ID and limit.
        // Example: profiles?select=*&id=eq.some-uuid&limit=1
        let urlString = "\(super.endpoint(EndPoint.profile.rawValue))&id=eq.\(videoOwnerId)&limit=1"
        
        // Perform the GET request.
        self.get(url: urlString, responseModelType: [UserModel].self, completion: completion)
    }
}


// MARK: - NetworkMonitor
/// Singleton class to monitor network connectivity status.
/// Provides a simple way to check if the device is connected to a network.
class NetworkMonitor {
    
    // Shared singleton instance.
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background) // Monitor on a background queue
    
    /// `true` if the device has an active network connection, `false` otherwise.
    /// Updated automatically by the path monitor.
    private(set) var isConnected: Bool = true // Assume connected initially until first update.

    private init() {
        startMonitoring()
    }

    /// Starts monitoring network path updates.
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            // For debugging or reacting to changes:
            // print("Network is \(self?.isConnected == true ? "connected" : "disconnected")")
        }
        monitor.start(queue: queue)
    }
}
