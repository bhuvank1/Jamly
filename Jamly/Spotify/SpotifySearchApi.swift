//
//  SpotifySearchApi.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import Foundation

final class SpotifySearchApi {
    static let shared = SpotifySearchApi()
    private init() {}

    private var task: URLSessionDataTask?

    //Search tracks with a 1 attempt retry (refreshes token)
    func searchTracks(query: String, limit: Int = 15, completion: @escaping (Result<[Track], Error>) -> Void) {
        // cancel any in progress requests
        task?.cancel()

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            completion(.success([]))
            return
        }

        // Valid request on going, get a up to date token
        SpotifyAuthManager.shared.getValidAccessToken { token in
            guard let token = token else {
                completion(.failure(NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
                return
            }
            //if we have a valid token then search
            self.performSearch(query: q, limit: limit, token: token, attempt: 0, completion: completion)
        }
    }

    // Private helper function that handles the actual logic of the search
    private func performSearch(query: String, limit: Int, token: String, attempt: Int, completion: @escaping (Result<[Track], Error>) -> Void) {

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.spotify.com/v1/search?q=\(encoded)&type=track&limit=\(limit)")!

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        task = URLSession.shared.dataTask(with: req) { data, resp, err in
            // If user typed again and we canceled just return 
            if let err = err as NSError?, err.code == NSURLErrorCancelled { return }

            if let err = err {
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            }

            guard let http = resp as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "HTTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])))
                }
                return
            }

            // Handle 401 with one refresh attempt
            if http.statusCode == 401, attempt == 0 {
                SpotifyAuthManager.shared.getValidAccessToken { newToken in
                    guard let newToken = newToken else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])))
                        }
                        return
                    }
                    self.performSearch(query: query, limit: limit, token: newToken, attempt: 1, completion: completion)
                }
                return
            }

            // Handle 429 rate limit
            if http.statusCode == 429, attempt == 0 {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init) ?? 1
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryAfter)) {
                    self.performSearch(query: query, limit: limit, token: token, attempt: 1, completion: completion)
                }
                return
            }

            // Any other non-200 just gives the error
            if http.statusCode != 200 {
                let message: String
                if let data = data,
                   let body = String(data: data, encoding: .utf8),
                   !body.isEmpty {
                    message = "HTTP \(http.statusCode): \(body)"
                } else {
                    message = "HTTP \(http.statusCode)"
                }
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "HTTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            // Parse Spotify -> Track[]
            do {
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let items = (root?["tracks"] as? [String: Any])?["items"] as? [[String: Any]] ?? []

                let tracks: [Track] = items.compactMap { it in
                    guard
                        let id = it["id"] as? String,
                        let name = it["name"] as? String,
                        let artistsArr = it["artists"] as? [[String: Any]],
                        let duration = it["duration_ms"] as? Int
                    else { return nil }

                    let artistNames = artistsArr.compactMap { $0["name"] as? String }.joined(separator: ", ")
                    let album = it["album"] as? [String: Any]
                    let images = album?["images"] as? [[String: Any]]
                    let art = images?.dropFirst().first?["url"] as? String

                    return Track(id: id, name: name, artists: artistNames, duration_ms: duration, albumArt: art)
                }

                DispatchQueue.main.async { completion(.success(tracks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }

        task?.resume()
    }
}
