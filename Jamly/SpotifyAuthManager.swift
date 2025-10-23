//
//  SpotifyAuthManager.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import Foundation
import CryptoKit
import AuthenticationServices

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
