//
//  BaseAPIService.swift
//  GolfAppDemo // TODO: Consider renaming project/module if this is from a template.
//
//  Created by Kavin's Macbook on 22/05/25.
//
//  Provides fundamental API service capabilities, including generic GET requests
//  and base URL configuration. Also handles SSL pinning if configured.
//

import UIKit
import Foundation

// MARK: - APIServiceError
/// Custom error types specific to API service operations.
enum APIServiceError: LocalizedError {
    case invalidURL         // Indicates that the constructed URL string is malformed.
    case blankResponse      // Indicates that the server returned no data.
    // Add other common API errors here if needed (e.g., authenticationFailed, decodingErrorWrapper(Error))

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .blankResponse:
            return "The server returned an empty response."
        }
    }
}

// MARK: - BaseAPIService
/// A base class for API services, providing common functionality like base URL construction
/// and a generic GET request method. It also includes SSL pinning capabilities via `URLSessionDelegate`.
class BaseAPIService: NSObject {
    
    // MARK: - Configuration Constants
    /// The base URL for all API requests.
    private let baseURL: String = "https://cbtzdoasmkbbiwnyoxvz.supabase.co/rest/"
    /// The API version string, appended to the base URL.
    private let apiVersion: String = "v1"
    /// The API key used for authenticating requests.
    private let authKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYzNjM4MjEwOCwiZXhwIjoxOTUxOTU4MTA4fQ.YdFG3RUvDJmRHoUQV4C5TsZcg2moGDDmnr4RNKO-Bcg" // TODO: Securely store API keys, not hardcoded.
        
    /// Constructs the full URL string for a given endpoint.
    /// - Parameter endpointPath: The specific path for the API endpoint (e.g., "users", "videos/latest").
    /// - Returns: A complete URL string.
    func endpoint(_ endpointPath: String) -> String {
        return "\(baseURL)\(apiVersion)/\(endpointPath)"
    }
    
    /// Performs a generic GET request to the specified URL and decodes the response.
    /// - Parameters:
    ///   - urlString: The full URL string for the GET request.
    ///   - responseModelType: The `Decodable` model type that the JSON response is expected to conform to.
    ///   - completion: A closure called with the `Result` of the operation, containing either the decoded model or an `Error`.
    func get<T: Decodable>(url urlString: String, responseModelType: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        
        guard let url = URL(string: urlString) else {
            completion(.failure(APIServiceError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(authKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Accept") // Good practice to specify accept header
        
        // For debugging: Print the equivalent cURL command.
        // print("cURL Request: \(request.cURL())")
        
        // Using an ephemeral session configuration means no caching or persistent storage.
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        
        session.dataTask(with: request) { data, response, error in
            // Handle network-level errors (e.g., no internet connection).
            if let error = error {
                print(" Network Error: \(error.localizedDescription) for URL: \(urlString)")
                completion(.failure(error))
                return
            }
            
            // Ensure data is present.
            guard let data = data else {
                print(" Blank Response for URL: \(urlString)")
                completion(.failure(APIServiceError.blankResponse))
                return
            }

            // Optional: Log raw response for debugging.
            // if let jsonString = String(data: data, encoding: .utf8) {
            //     print("Raw JSON Response for \(urlString): \(jsonString)")
            // }
            
            do {
                let decoder = JSONDecoder()
                // Configure decoder if necessary (e.g., dateDecodingStrategy, keyDecodingStrategy)
                // decoder.keyDecodingStrategy = .convertFromSnakeCase // If API uses snake_case keys
                let decodedResponse = try decoder.decode(responseModelType.self, from: data)
                completion(.success(decodedResponse))
            } catch let decodingError {
                print(" Decoding Error: \(decodingError.localizedDescription) for URL: \(urlString)")
                // Provide more context for decoding errors if possible
                // if let jsonString = String(data: data, encoding: .utf8) {
                //     print("Failed to decode JSON: \(jsonString)")
                // }
                completion(.failure(decodingError))
            }
        }.resume() // Start the data task.
    }
}

// MARK: - URLSessionDelegate (SSL Pinning)
extension BaseAPIService: URLSessionDelegate {
    
    /// Handles server trust authentication challenges, allowing for SSL pinning.
    /// - Warning: SSL pinning can make your app more secure but requires careful management of certificates.
    ///   If the server's certificate changes and your app isn't updated, network requests will fail.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Define the hosts for which SSL pinning should be enforced.
        // These should exactly match the host in challenge.protectionSpace.host.
        let trustedHosts = ["cbtzdoasmkbbiwnyoxvz.supabase.co"] // Note: Removed "/rest/" as host does not include path.
        
        // Check if the challenge is for server trust and the host is one of our trusted hosts.
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           trustedHosts.contains(challenge.protectionSpace.host),
           let serverTrust = challenge.protectionSpace.serverTrust {
            
            // TODO: Implement actual public key pinning or certificate pinning logic here.
            // For now, this example uses the server's provided trust, which is default behavior
            // but structured to allow for pinning logic to be inserted.
            // Using .useCredential with the serverTrust effectively accepts the server's certificate if the host matches.
            // True pinning would involve comparing the serverTrust against a known public key or certificate.
            
            let credential = URLCredential(trust: serverTrust)
            // challenge.sender?.use(credential, for: challenge) // Not needed if we complete with .useCredential
            completionHandler(.useCredential, credential)
        } else {
            // For other hosts or authentication methods, perform default handling.
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - URLRequest cURL Extension
public extension URLRequest {
    
    /// Generates a cURL command string representation of the `URLRequest`. Useful for debugging.
    /// - Returns: A string that can be pasted into a terminal to execute the request using cURL.
    func cURL() -> String {
        var components = ["curl -v"] // Use -v for verbose output

        // Method
        if let httpMethod = self.httpMethod {
            components.append("-X \(httpMethod)")
        }

        // URL
        if let url = self.url {
            components.append("'\(url.absoluteString)'")
        }

        // Headers
        if let headerFields = self.allHTTPHeaderFields {
            for (key, value) in headerFields {
                components.append("-H '\(key): \(value)'")
            }
        }

        // Body
        if let httpBodyData = self.httpBody, let httpBodyString = String(data: httpBodyData, encoding: .utf8) {
            let escapedBody = httpBodyString.replacingOccurrences(of: "'", with: "'''") // Escape single quotes
            components.append("-d '\(escapedBody)'")
        }
        
        return components.joined(separator: " \\\n\t") // Multi-line format for readability
    }
}
