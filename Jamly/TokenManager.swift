//
//  TokenManager.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//


import Foundation

final class TokenManager {
    static let shared = TokenManager()
    private init() {}

    // Hardcoding secrets is insecure. Replace with PKCE ASAP and reset Spotify App dashboard
    private let clientID = "6b5771b30c644a27a476700829233bbc"
    private let clientSecret = "30d3a879721742be8bc8cd531c0888d9"

    private let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!

    // Cache
    private var accessToken: String?
    private var expiry: Date?

    // Avoid concurrent refreshes
    private let queue = DispatchQueue(label: "token.manager.queue")

    // Get a valid bearer token, refreshing if needed.
    func getValidToken(completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            // If token exists and expires in >60s, reuse it
            if let token = self.accessToken,
               let exp = self.expiry,
               Date() < exp.addingTimeInterval(-60) {
                DispatchQueue.main.async { completion(.success(token)) }
                return
            }
            // Otherwise request a new app token
            self.fetchAppToken { result in
                DispatchQueue.main.async { completion(result) }
            }
        }
    }

    // Reset token
    func invalidate() {
        queue.async {
            self.accessToken = nil
            self.expiry = nil
        }
    }

    private func fetchAppToken(completion: @escaping (Result<String, Error>) -> Void) {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Basic <base64(clientID:clientSecret)>
        let basic = "\(clientID):\(clientSecret)"
            .data(using: .utf8)!
            .base64EncodedString()
        req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")

        let body = "grant_type=client_credentials"
        req.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Double
            else {
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "Token", code: status, userInfo: nil)))
                return
            }

            self.queue.async {
                self.accessToken = token
                self.expiry = Date().addingTimeInterval(expiresIn)
            }
            completion(.success(token))
        }.resume()
    }
}
