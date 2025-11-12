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

final class SpotifyAuthManager : NSObject { //NSObject needed for ASWebAuth
    
    static let shared = SpotifyAuthManager()
    private override init() {}
    
    //constant setup
    private let clientID = SpotifyAuthConfig.clientID
    private let redirectURI = SpotifyAuthConfig.redirectURI
    private let authorizeURL = SpotifyAuthConfig.authorizeURL
    private let tokenURL = SpotifyAuthConfig.tokenURL
    private let scopes = SpotifyAuthConfig.scopes
    
    //Storage
    private var accessToken: String?
    private var refreshToken: String?
    private var expiry: Date?
    
    //PKCE
    private var codeVerifier: String?
    private var session: ASWebAuthenticationSession?
        
    //Start spotify login sequence using Authorization code and PKCE
    func signIn(completion: @escaping (Bool) -> Void) {
        let verifier = PKCE.makeVerifier()
        codeVerifier = verifier
        let challenge = PKCE.challenge(from: verifier)
        
        //build URL
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scopes.joined(separator: " ")),   // can be ""
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "state", value: UUID().uuidString)
        ]
        
        guard let authURL = components.url else { completion(false); return }
        
        session = ASWebAuthenticationSession( url: authURL, callbackURLScheme: URL(string: redirectURI)?.scheme) { [weak self] callbackURL, error in guard let self else { completion(false); return }
            guard error == nil, let callbackURL else { completion(false); return }
            
            // 4) Extract the ?code= from the callback
            guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = self.codeVerifier
            else { completion(false); return }

            // 5) Exchange code for tokens
            self.exchangeCodeforTokens(code: code, verifier: verifier) { ok in
                guard ok else { return }
                // If token exchange was successfull update cache
                self.cacheSpotifyStatsForCurrentUser() { _ in }
                completion(ok)
            }
        }
        
        session?.presentationContextProvider = self
        _ = session?.start()
    }
    
    //Helper function to make the actual POST Api Call
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
        
        //make the API Call
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access = json["access_token"] as? String,
                let expiresIn = json["expires_in"] as? Double
            else { completion(false); return } //Expected json not found

            self.accessToken = access //successful query
            self.expiry = Date().addingTimeInterval(expiresIn)
            if let r = json["refresh_token"] as? String {
                self.refreshToken = r
            }
            completion(true)
        }.resume()

    }
    
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
    
    //Code to regenerate the short-term access token (1 hr) using the refresh token
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
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Double
            else { completion(false); return }

            self.accessToken = access
            self.expiry = Date().addingTimeInterval(expiresIn)
            if let newRefresh = json["refresh_token"] as? String { self.refreshToken = newRefresh }
            completion(true)
        }.resume()
    }
    
    func clearTokens() {
        accessToken = nil
        refreshToken = nil
        expiry = nil
    }
    
    // MARK: Helper to cache spotify statistics
    
    //Helper to run the entire caching process
    func cacheSpotifyStatsForCurrentUser(completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { completion(false); return }
        getValidAccessToken { token in
            guard let token = token else { completion(false); return }

            // 1) Fetch top tracks + top artists (short_term)
            let limit = 10 //limit variable for the request
            let topTracksURL = URL(string: "https://api.spotify.com/v1/me/top/tracks?time_range=short_term&limit=\(limit)")!
            let topArtistsURL = URL(string: "https://api.spotify.com/v1/me/top/artists?time_range=short_term&limit=\(limit)")!

            self.fetchJSON(token: token, url: topTracksURL) { tracksJSON in
                self.fetchJSON(token: token, url: topArtistsURL) { artistsJSON in

                    // Collect track IDs for audio-features
                    let trackIDs: [String] = (tracksJSON["items"] as? [[String: Any]] ?? [])
                        .compactMap { $0["id"] as? String }

                    self.fetchAudioFeatures(token: token, trackIDs: trackIDs) { featuresMap in
                        // Build payload
                        let payload = self.buildStatsPayload(
                            tracksJSON: tracksJSON,
                            artistsJSON: artistsJSON,
                            featuresByTrackId: featuresMap
                        )

                        // 3) Write to Firestore
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

    // Collect Audio features for up to 100 tracks (spotify limit)
    private func fetchAudioFeatures(token: String,
                                    trackIDs: [String],
                                    completion: @escaping ([String: (tempo: Double?, energy: Double?)]) -> Void) {
        guard !trackIDs.isEmpty else { completion([:]); return }

        // Up to 100 ids per call
        let chunks = stride(from: 0, to: trackIDs.count, by: 100).map { Array(trackIDs[$0..<min($0+100, trackIDs.count)]) }
        let g = DispatchGroup()
        var out: [String: (Double?, Double?)] = [:]

        for chunk in chunks {
            g.enter()
            let ids = chunk.joined(separator: ",")
            let url = URL(string: "https://api.spotify.com/v1/audio-features?ids=\(ids)")!
            fetchJSON(token: token, url: url) { json in
                if let arr = json["audio_features"] as? [[String: Any]] {
                    for feat in arr {
                        if let id = feat["id"] as? String {
                            let tempo = feat["tempo"] as? Double
                            let energy = feat["energy"] as? Double
                            out[id] = (tempo, energy)
                        }
                    }
                }
                g.leave()
            }
        }

        g.notify(queue: .global()) { completion(out) }
    }


    // Builds the actual data structure to be stored
    private func buildStatsPayload(tracksJSON: [String: Any],
                                   artistsJSON: [String: Any],
                                   featuresByTrackId: [String: (tempo: Double?, energy: Double?)]) -> [String: Any] {

        // Map Top Tracks -> [{id,name,artists[],tempo?,energy?}]
        let trackItems = (tracksJSON["items"] as? [[String: Any]] ?? [])
        var tempoVals: [Double] = []
        var energyVals: [Double] = []

        let topTracks: [[String: Any]] = trackItems.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let name = (t["name"] as? String) ?? "(unknown)"
            let artistNames: [String] = (t["artists"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }

            let feats = featuresByTrackId[id]
            if let tempo = feats?.tempo { tempoVals.append(tempo) }
            if let energy = feats?.energy { energyVals.append(energy) }

            var dict: [String: Any] = [
                "id": id,
                "name": name,
                "artists": artistNames
            ]
            if let tempo = feats?.tempo { dict["tempo"] = tempo }
            if let energy = feats?.energy { dict["energy"] = energy }
            return dict
        }

        // Map Top Artists -> [{id,name,genres[]}]
        let artistItems = (artistsJSON["items"] as? [[String: Any]] ?? [])
        let topArtists: [[String: Any]] = artistItems.compactMap { a in
            guard let id = a["id"] as? String else { return nil }
            let name = (a["name"] as? String) ?? "(unknown)"
            let genres = (a["genres"] as? [String]) ?? []
            return ["id": id, "name": name, "genres": genres]
        }

        // Build genre weights from artist genres (simple normalized frequency)
        var genreCount: [String: Int] = [:]
        for a in artistItems {
            let genres = (a["genres"] as? [String]) ?? []
            for g in genres {
                genreCount[g.lowercased(), default: 0] += 1
            }
        }
        let total = max(1, genreCount.values.reduce(0, +))
        let genresWeighted: [[String: Any]] = genreCount
            .map { ["name": $0.key, "weight": Double($0.value) / Double(total)] }
            .sorted { ($0["weight"] as? Double ?? 0) > ($1["weight"] as? Double ?? 0) }

        // Calculated Averages to generate user tempo and energy
        let tempoAvg = tempoVals.isEmpty ? nil : (tempoVals.reduce(0,+) / Double(tempoVals.count))
        let energyAvg = energyVals.isEmpty ? nil : (energyVals.reduce(0,+) / Double(energyVals.count))

        return [
            "topTracks": topTracks,
            "topArtists": topArtists,
            "genres": genresWeighted,
            "tempoAvg": tempoAvg as Any,
            "energyAvg": energyAvg as Any
        ]
    }
    
}

//code snip from online for ASWeb protocol
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
        
        //failure fallback
        return UIWindow(frame: .zero)
    }
}

enum PKCE {
    //chat GPT converted Javascript functions from the developer.spotify website for the verfier and challenge
    
    static func makeVerifier(length: Int = 64) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    static func challenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        let b64 = Data(hash).base64EncodedString()
        return b64.replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
    }
}


enum SpotifyAuthConfig {
    static let clientID = "6b5771b30c644a27a476700829233bbc"
    static let redirectURI = "jamly://auth-callback"

    static let scopes = ["user-read-email", "user-read-private", "user-top-read"]
    static let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
}
