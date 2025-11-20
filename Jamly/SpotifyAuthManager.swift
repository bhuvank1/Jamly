//
//  SpotifyAuthManager.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import Foundation
import CryptoKit
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import UIKit

final class SpotifyAuthManager: NSObject { // NSObject needed for ASWebAuth
    
    static let shared = SpotifyAuthManager()
    private override init() {}
    
    // Constant setup
    private let clientID = SpotifyAuthConfig.clientID
    private let redirectURI = SpotifyAuthConfig.redirectURI
    private let authorizeURL = SpotifyAuthConfig.authorizeURL
    private let tokenURL = SpotifyAuthConfig.tokenURL
    private let scopes = SpotifyAuthConfig.scopes
    
    // Storage
    private var accessToken: String?
    private var refreshToken: String?
    private var expiry: Date?
    
    // PKCE
    private var codeVerifier: String?
    private var session: ASWebAuthenticationSession?
    
    // MARK: - Public Auth
    
    /// Start Spotify login sequence using Authorization Code + PKCE
    func signIn(completion: @escaping (Bool) -> Void) {
        let verifier = PKCE.makeVerifier()
        codeVerifier = verifier
        let challenge = PKCE.challenge(from: verifier)
        
        // Build authorize URL
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scopes.joined(separator: " ")),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "state", value: UUID().uuidString)
        ]
        
        guard let authURL = components.url else { completion(false); return }
        
        session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: URL(string: redirectURI)?.scheme
        ) { [weak self] callbackURL, error in
            guard let self else { completion(false); return }
            guard error == nil, let callbackURL else { completion(false); return }
            
            // Extract ?code=
            guard
                let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value,
                let verifier = self.codeVerifier
            else {
                completion(false); return
            }
            
            // Exchange code for tokens
            self.exchangeCodeforTokens(code: code, verifier: verifier) { ok in
                guard ok else { completion(false); return }
                // Optionally cache initial stats right after sign-in
                self.cacheSpotifyStatsForCurrentUser() { _ in }
                completion(true)
            }
        }
        
        session?.presentationContextProvider = self
        _ = session?.start()
    }
    
    func disconnect() {
        // clear in-memory tokens
        clearTokens()

        // clear cached Firestore "connected" state
        if let uid = Auth.auth().currentUser?.uid {
            Firestore.firestore().collection("userInfo").document(uid).setData([
                "spotify": [
                    "connected": false,
                    "lastUpdatedAt": Int(Date().timeIntervalSince1970),
                    "stats": [:]
                ]
            ], merge: true)
        }

        // end the current sign-in session (cleanup)
        session?.cancel()
        session = nil
        codeVerifier = nil
    }
    
    // Returns a valid short-lived token (refreshes if needed)
    func getValidAccessToken(completion: @escaping (String?) -> Void) {
        if let token = accessToken, let e = expiry, Date() < e.addingTimeInterval(-60) {
            completion(token); return
        }
        guard let refresh = refreshToken else {
            completion(nil); return
        }
        refreshAccessToken(refreshToken: refresh) { ok in
            completion(ok ? self.accessToken : nil)
        }
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        expiry = nil
    }
    
    // MARK: - Token Exchange / Refresh
    
    private func exchangeCodeforTokens(code: String, verifier: String, completion: @escaping (Bool) -> Void) {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        
        let body = [
            "client_id=\(clientID)",
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&")
        
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access = json["access_token"] as? String,
                let expiresIn = json["expires_in"] as? Double
            else { completion(false); return }
            
            self.accessToken = access
            self.expiry = Date().addingTimeInterval(expiresIn)
            if let r = json["refresh_token"] as? String {
                self.refreshToken = r
            }
            completion(true)
        }.resume()
    }
    
    private func refreshAccessToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        
        let body = [
            "client_id=\(SpotifyAuthConfig.clientID)",
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)"
        ].joined(separator: "&")
        
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access = json["access_token"] as? String,
                let expiresIn = json["expires_in"] as? Double
            else { completion(false); return }
            
            self.accessToken = access
            self.expiry = Date().addingTimeInterval(expiresIn)
            if let newRefresh = json["refresh_token"] as? String {
                self.refreshToken = newRefresh
            }
            completion(true)
        }.resume()
    }
        
    // Fetch top tracks + top artists and store derived genres. No tempo/energy.
    func cacheSpotifyStatsForCurrentUser(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { completion(false); return }
        getValidAccessToken { token in
            guard let token = token else { completion(false); return }
            
            let limit = 10
            let topTracksURL = URL(string: "https://api.spotify.com/v1/me/top/tracks?time_range=short_term&limit=\(limit)")!
            let topArtistsURL = URL(string: "https://api.spotify.com/v1/me/top/artists?time_range=short_term&limit=\(limit)")!
            
            self.fetchJSON(token: token, url: topTracksURL) { tracksJSON in
                self.fetchJSON(token: token, url: topArtistsURL) { artistsJSON in
                    
                    // Build payload WITHOUT audio features
                    let payload = self.buildStatsPayload(
                        tracksJSON: tracksJSON,
                        artistsJSON: artistsJSON
                    )
                    
                    Firestore.firestore().collection("userInfo").document(uid).setData([
                        "spotify": [
                            "connected": true,
                            "lastUpdatedAt": Int(Date().timeIntervalSince1970),
                            "stats": payload
                        ]
                    ], merge: true) { err in
                        completion(err == nil)
                    }
                }
            }
        }
    }
        
    private func fetchJSON(token: String, url: URL, completion: @escaping ([String: Any]) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            completion(json)
        }.resume()
    }
        
    // Builds the Firestore stats object: { topTracks, topArtists, genres }
    private func buildStatsPayload(
        tracksJSON: [String: Any],
        artistsJSON: [String: Any]
    ) -> [String: Any] {
        
        // Top Tracks -> [{id, name, artists[]}]
        let trackItems = (tracksJSON["items"] as? [[String: Any]] ?? [])
        let topTracks: [[String: Any]] = trackItems.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let name = (t["name"] as? String) ?? "(unknown)"
            let artistNames: [String] = (t["artists"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }
            return [
                "id": id,
                "name": name,
                "artists": artistNames
            ]
        }
        
        // Top Artists -> [{id, name, genres[]}]
        let artistItems = (artistsJSON["items"] as? [[String: Any]] ?? [])
        let topArtists: [[String: Any]] = artistItems.compactMap { a in
            guard let id = a["id"] as? String else { return nil }
            let name = (a["name"] as? String) ?? "(unknown)"
            let genres = (a["genres"] as? [String]) ?? []
            return ["id": id, "name": name, "genres": genres]
        }
        
        // Genre weights from artist genres (normalized frequency)
        var genreCount: [String: Int] = [:]
        for a in artistItems {
            let genres = (a["genres"] as? [String]) ?? []
            for g in genres { genreCount[g.lowercased(), default: 0] += 1 }
        }
        let total = max(1, genreCount.values.reduce(0, +))
        let genresWeighted: [[String: Any]] = genreCount
            .map { ["name": $0.key, "weight": Double($0.value) / Double(total)] }
            .sorted { ($0["weight"] as? Double ?? 0) > ($1["weight"] as? Double ?? 0) }
        
        return [
            "topTracks": topTracks,
            "topArtists": topArtists,
            "genres": genresWeighted
        ]
    }
}

// ASWebAuthenticationPresentationContextProviding Helper
extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window for the current scene
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        
        // Prefer the key window of that scene
        if let window = windowScene?.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // Fallback
        return UIWindow(frame: .zero)
    }
}

// PKCE Helpers
enum PKCE {
    // Converted from Spotify developer docs (JS -> Swift)
    static func makeVerifier(length: Int = 64) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
    
    static func challenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        let b64 = Data(hash).base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

//Static config
enum SpotifyAuthConfig {
    static let clientID = "6b5771b30c644a27a476700829233bbc"
    static let redirectURI = "jamly://auth-callback"
    static let scopes = ["user-read-email", "user-read-private", "user-top-read"]
    static let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
}
