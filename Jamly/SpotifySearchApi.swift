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

    private var task: URLSessionDataTask? //keep reference to current search so that it can be cancelled on a new search

    func searchTracks(query: String, limit: Int = 15, completion: @escaping (Result<[Track], Error>) -> Void) {
        task?.cancel()
        //Code to cancel current requests so old results are not rendered

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { completion(.success([])); return }

        TokenManager.shared.getValidToken { tokenResult in //get token using class
            switch tokenResult {
            case .failure(let e):
                completion(.failure(e))

            case .success(let token): //Build the search and query with token
                let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let url = URL(string: "https://api.spotify.com/v1/search?q=\(encoded)&type=track&limit=\(limit)")!

                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                self.task = URLSession.shared.dataTask(with: req) { data, resp, err in
                    if let err = err as NSError?, err.code == NSURLErrorCancelled { return }
                    if let err = err { DispatchQueue.main.async { completion(.failure(err)) }; return }

                    // If token somehow invalid, nuke and retry once
                    if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
                        TokenManager.shared.invalidate()
                        self.searchTracks(query: query, limit: limit, completion: completion)
                        return
                    }

                    guard let data = data else { DispatchQueue.main.async { completion(.success([])) }; return }

                    do {
                        // Parse json down to Track class for deocding
                        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        let items = (root?["tracks"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
                        let tracks: [Track] = items.compactMap { it in
                            guard let id = it["id"] as? String,
                                  let name = it["name"] as? String,
                                  let artists = it["artists"] as? [[String: Any]],
                                  let duration = it["duration_ms"] as? Int else { return nil }
                            let artistNames = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
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
                self.task?.resume()
            }
        }
    }
}
    
