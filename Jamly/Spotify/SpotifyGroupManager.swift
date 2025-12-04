//
//  SpotifyGroupManager.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/11/25.
//  Personally Created reccomendation system that doesnt use /reccomendation endpoint (not available to free apps)
//

import Foundation
import FirebaseFirestore

// Stats models

struct SpotifyTrack: Hashable {
    let id: String
    let name: String
    let artists: [String]
}

struct SpotifyArtist: Hashable {
    let id: String
    let name: String
    let genres: [String]
}

struct SpotifyGenreWeight: Hashable {
    let name: String
    let weight: Double
}

struct SpotifyStats {
    let topTracks: [SpotifyTrack]
    let topArtists: [SpotifyArtist]
    let genres: [SpotifyGenreWeight]
}

final class SpotifyGroupManager {
    static let shared = SpotifyGroupManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // PUBLIC: generate recs client-side with allowed endpoints only
    // Uses cached user-top-read (from Firestore), /artists/{id}/top-tracks, /tracks, and /search (type=track).
    func generateLiveRecommendationsViaSpotify(
        for group: Group,
        limit: Int = 20,
        market: String = "US",
        completion: @escaping ([Track]) -> Void
    ) {
        let uids = group.members
        print("generateGroupRecs(client-side): \(group.name) members=\(uids.count)")
        guard !uids.isEmpty else { completion([]); return }
        
        fetchStats(for: uids) { [weak self] uidToStats in
            guard let self = self, !uidToStats.isEmpty else { completion([]); return }
            print("Fetched stats for \(uidToStats.count) members")
            
            // 1) build seeds + weights from group cache
            let (seeds, weights) = self.buildGroupSeedsAndWeights(
                uidToStats: uidToStats,
                maxArtistSeeds: 5,
                maxTrackSeeds: 5,
                maxGenreSeeds: 5
            )
            print("Seeds: artists=\(seeds.artistIDs.count) tracks=\(seeds.trackIDs.count) genres=\(seeds.genres.count)")
            
            // 2) use CURRENT USER token
            SpotifyAuthManager.shared.getValidAccessToken { token in
                guard let token = token else { print("No Spotify token"); completion([]); return }
                
                // 3) fetch candidates from artist top-tracks + genre search (+ include seed tracks)
                self.fetchCandidates(
                    token: token,
                    artistSeeds: seeds.artistIDs,
                    trackSeeds: seeds.trackIDs,
                    genreSeeds: seeds.genres,
                    market: market
                ) { candidates in
                    // 4) rank + diversify
                    let ranked = self.rankCandidates(
                        candidates,
                        weights: weights,
                        maxPerArtist: 2
                    )
                    let out = Array(self.toAppTracks(ranked).prefix(limit))
                    completion(out)
                }
            }
        }
    }
}

// Firestore helpers

extension SpotifyGroupManager {
    private func fetchStats(for uids: [String], completion: @escaping ([String: SpotifyStats]) -> Void) {
        var results: [String: SpotifyStats] = [:]
        let chunks = stride(from: 0, to: uids.count, by: 10).map { Array(uids[$0..<min($0+10, uids.count)]) }
        let g = DispatchGroup()
        
        for chunk in chunks {
            g.enter()
            db.collection("userInfo")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snapshot, _ in
                    defer { g.leave() }
                    guard let docs = snapshot?.documents else { return }
                    for d in docs {
                        if let stats = self.parseSpotifyStats(from: d) {
                            results[d.documentID] = stats
                        }
                    }
                }
        }
        g.notify(queue: .main) { completion(results) }
    }
    
    private func parseSpotifyStats(from userDoc: DocumentSnapshot) -> SpotifyStats? {
        guard
            let data = userDoc.data(),
            let spotify = data["spotify"] as? [String: Any],
            let stats = spotify["stats"] as? [String: Any]
        else { return nil }
        
        // topTracks
        let topTracksRaw = stats["topTracks"] as? [[String: Any]] ?? []
        let topTracks: [SpotifyTrack] = topTracksRaw.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let name = (t["name"] as? String) ?? "(unknown)"
            let artists = (t["artists"] as? [String]) ?? []
            return SpotifyTrack(id: id, name: name, artists: artists)
        }
        
        // topArtists
        let topArtistsRaw = stats["topArtists"] as? [[String: Any]] ?? []
        let topArtists: [SpotifyArtist] = topArtistsRaw.compactMap { a in
            guard let id = a["id"] as? String else { return nil }
            let name = (a["name"] as? String) ?? "(unknown)"
            let genres = (a["genres"] as? [String]) ?? []
            return SpotifyArtist(id: id, name: name, genres: genres)
        }
        
        if topTracksRaw.isEmpty && topArtistsRaw.isEmpty {
            print("\(userDoc.documentID) stats empty: no topTracks/topArtists")
        }
        
        // genres
        let genresRaw = stats["genres"] as? [[String: Any]] ?? []
        let genres: [SpotifyGenreWeight] = genresRaw.compactMap { g in
            guard let name = g["name"] as? String else { return nil }
            let weight = g["weight"] as? Double ?? 0.0
            return SpotifyGenreWeight(name: name.lowercased(), weight: max(0, weight))
        }
        
        return SpotifyStats(topTracks: topTracks, topArtists: topArtists, genres: genres)
    }
}

// Seeding helpers

extension SpotifyGroupManager {
    private struct Seeds {
        var artistIDs: [String] = []
        var trackIDs:  [String] = []
        var genres:    [String] = [] // plain names (lowercased); used in search
    }
    
    private struct Weights {
        var artistCentrality: [String: Double] // artistId -> [0,1]
        var trackFrequency:   [String: Double] // trackId  -> [0,1]
        var genreWeight:      [String: Double] // genre    -> [0,1]
    }
    
    private func buildGroupSeedsAndWeights(
        uidToStats: [String: SpotifyStats],
        maxArtistSeeds: Int,
        maxTrackSeeds: Int,
        maxGenreSeeds: Int
    ) -> (Seeds, Weights) {
        var artistCounts: [String: Int] = [:]
        var trackCounts:  [String: Int] = [:]
        var genreAgg:     [String: Double] = [:]
        
        for (_, s) in uidToStats {
            for a in Set(s.topArtists.map { $0.id }) { artistCounts[a, default: 0] += 1 }
            for t in Set(s.topTracks.map { $0.id }) { trackCounts[t,  default: 0] += 1 }
            for gw in s.genres { genreAgg[gw.name, default: 0.0] += gw.weight }
        }
        
        let maxA = max(1, artistCounts.values.max() ?? 1)
        let artistCentrality = artistCounts.mapValues { Double($0) / Double(maxA) }
        
        let maxT = max(1, trackCounts.values.max() ?? 1)
        let trackFrequency = trackCounts.mapValues { Double($0) / Double(maxT) }
        
        let totalG = max(1e-9, genreAgg.values.reduce(0.0, +))
        let genreWeight = genreAgg.mapValues { $0 / totalG }
        
        let topArtistIDs = artistCounts.sorted { (a, b) in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.map { $0.key }
        let topTrackIDs = trackCounts.sorted { (a, b) in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.map { $0.key }
        let topGenres = genreWeight.sorted { $0.value > $1.value }.map { $0.key }
        
        var seeds = Seeds()
        seeds.artistIDs = Array(topArtistIDs.prefix(maxArtistSeeds))
        seeds.trackIDs  = Array(topTrackIDs.prefix(maxTrackSeeds))
        seeds.genres    = Array(topGenres.prefix(maxGenreSeeds))
        
        return (seeds, Weights(artistCentrality: artistCentrality,
                               trackFrequency: trackFrequency,
                               genreWeight: genreWeight))
    }
}

// Actual fetching helper

extension SpotifyGroupManager {
    private struct RawTrack {
        let id: String
        let name: String
        let artistIDs: [String]
        let artistNames: [String]
        let popularity: Int // 0..100
        let albumImageURL: String?
        let durationMs: Int
    }
    
    private func fetchCandidates(
        token: String,
        artistSeeds: [String],
        trackSeeds: [String],
        genreSeeds: [String],
        market: String,
        completion: @escaping ([RawTrack]) -> Void
    ) {
        let g = DispatchGroup()
        var tracksSet: [String: RawTrack] = [:] // de-dup
        
        // A) artist top-tracks (allowed)
        for artistID in artistSeeds {
            if let url = URL(string: "https://api.spotify.com/v1/artists/\(artistID)/top-tracks?market=\(market)") {
                g.enter()
                performGET(url: url, token: token) { json in
                    for t in self.parseTracksArray(json["tracks"] as? [[String: Any]] ?? []) {
                        tracksSet[t.id] = t
                    }
                    g.leave()
                }
            }
        }
        
        // B) include seed tracks themselves (bias to member overlap)
        if !trackSeeds.isEmpty {
            let chunks = stride(from: 0, to: trackSeeds.count, by: 50).map { Array(trackSeeds[$0..<min($0+50, trackSeeds.count)]) }
            for chunk in chunks {
                var comps = URLComponents(string: "https://api.spotify.com/v1/tracks")!
                comps.queryItems = [URLQueryItem(name: "ids", value: chunk.joined(separator: ","))]
                if let url = comps.url {
                    g.enter()
                    performGET(url: url, token: token) { json in
                        for t in self.parseTracksArray(json["tracks"] as? [[String: Any]] ?? []) {
                            tracksSet[t.id] = t
                        }
                        g.leave()
                    }
                }
            }
        }
        
        // C) genre-driven search (allowed): /search?type=track&q=genre:"xxx"
        // Limit results per genre to keep variety and avoid rate limits
        let perGenreLimit = 10
        for genre in genreSeeds {
            var comps = URLComponents(string: "https://api.spotify.com/v1/search")!
            // quote the genre if it has spaces
            let encodedGenre = genre.contains(" ") ? "\"\(genre)\"" : genre
            comps.queryItems = [
                URLQueryItem(name: "q", value: "genre:\(encodedGenre)"),
                URLQueryItem(name: "type", value: "track"),
                URLQueryItem(name: "market", value: market),
                URLQueryItem(name: "limit", value: String(perGenreLimit))
            ]
            if let url = comps.url {
                g.enter()
                performGET(url: url, token: token) { json in
                    let items = ((json["tracks"] as? [String: Any])?["items"] as? [[String: Any]]) ?? []
                    for t in self.parseTracksArray(items) {
                        tracksSet[t.id] = t
                    }
                    g.leave()
                }
            }
        }
        
        g.notify(queue: .global()) {
            completion(Array(tracksSet.values))
        }
    }
    
    private func performGET(url: URL, token: String, completion: @escaping ([String: Any]) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err { print("GET error: \(err.localizedDescription)") }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if code >= 400 { print("HTTP \(code) for \(url.absoluteString)") }
            let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            completion(json)
        }.resume()
    }
    
    private func parseTracksArray(_ arr: [[String: Any]]) -> [RawTrack] {
        return arr.compactMap { t in
            guard let id = t["id"] as? String else { return nil }
            let name = (t["name"] as? String) ?? "(unknown)"
            let popularity = (t["popularity"] as? Int) ?? 0
            let duration = (t["duration_ms"] as? Int) ?? 0
            
            let aObjs = (t["artists"] as? [[String: Any]] ?? [])
            let artistNames = aObjs.compactMap { $0["name"] as? String }
            let artistIDs   = aObjs.compactMap { $0["id"] as? String }
            
            var imageURL: String? = nil
            if
                let album = t["album"] as? [String: Any],
                let images = album["images"] as? [[String: Any]],
                let first = images.first,
                let url = first["url"] as? String
            {
                imageURL = url
            }
            
            return RawTrack(
                id: id,
                name: name,
                artistIDs: artistIDs,
                artistNames: artistNames,
                popularity: popularity,
                albumImageURL: imageURL,
                durationMs: duration
            )
        }
    }
}

// MARK: - Scoring & Diversification

extension SpotifyGroupManager {
    private struct ScoredTrack {
        let track: RawTrack
        let score: Double
    }
    
    // Rank candidates using group-centric signals only
    private func rankCandidates(_ candidates: [RawTrack],
                                weights: Weights,
                                maxPerArtist: Int) -> [ScoredTrack] {
        // Mix weights (tweak to taste)
        let W_artist: Double = 0.55  // group centrality
        let W_track:  Double = 0.20  // group familiarity with the exact track
        let W_pop:    Double = 0.25  // general quality / avoid too-obscure
        
        func pop01(_ p: Int) -> Double { max(0.0, min(1.0, Double(p) / 100.0)) }
        
        var scored: [ScoredTrack] = []
        scored.reserveCapacity(candidates.count)
        
        for c in candidates {
            let artistCent = (c.artistIDs.map { weights.artistCentrality[$0] ?? 0.0 }.max() ?? 0.0)
            let trackFreq  = weights.trackFrequency[c.id] ?? 0.0
            let pop        = pop01(c.popularity)
            let score      = (W_artist * artistCent) + (W_track * trackFreq) + (W_pop * pop)
            scored.append(ScoredTrack(track: c, score: score))
        }
        
        // sort high -> low
        scored.sort { $0.score > $1.score }
        
        // diversity: cap per leading artist
        var perArtistCount: [String: Int] = [:]
        var kept: [ScoredTrack] = []
        kept.reserveCapacity(scored.count)
        
        for s in scored {
            guard let mainArtist = s.track.artistIDs.first else { continue }
            if (perArtistCount[mainArtist] ?? 0) >= maxPerArtist { continue }
            perArtistCount[mainArtist, default: 0] += 1
            kept.append(s)
        }
        
        return kept
    }
    
    // Map RawTrack -> app Track model used elsewhere in your app
    private func toAppTracks(_ scored: [ScoredTrack]) -> [Track] {
        return scored.map { s in
            let t = s.track
            return Track(
                id: t.id,
                name: t.name,
                artists: t.artistNames.joined(separator: ", "),
                duration_ms: t.durationMs,
                albumArt: t.albumImageURL,
                image: nil
            )
        }
    }
}
