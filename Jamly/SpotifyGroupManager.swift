//
//  SpotifyGroupManager.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/11/25.
//

import Foundation
import FirebaseFirestore

//  Stats models

struct SpotifyTrack: Hashable {
    let id: String
    let name: String
    let artists: [String]
    let tempo: Double?
    let energy: Double?
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
    let tempoAvg: Double?
    let energyAvg: Double?
}

final class SpotifyGroupManager {
    static let shared = SpotifyGroupManager()
    private init() {}
    
    private let db = Firestore.firestore()

    // Logic flow: Build seeds from cached group stats, then make ONE final Spotify recommendations call.
    func generateLiveRecommendationsViaSpotify(for group: Group,
                                               limit: Int = 20,
                                               market: String? = nil, // e.g., "US"
                                               completion: @escaping ([Track]) -> Void) {
        let uids = group.members
        guard !uids.isEmpty else { completion([]); return }

        // 1) Read cached stats for all members
        fetchStats(for: uids) { [weak self] uidToStats in
            guard let self = self, !uidToStats.isEmpty else { completion([]); return }

            // 2) Build seeds + target params from the aggregate of cached stats
            let seeds   = self.buildGroupSeeds(uidToStats: uidToStats, maxTotalSeeds: 5)
            let targets = self.buildTargetParams(uidToStats: uidToStats)

            // 3) Create the /v1/recommendations URL
            guard let url = self.buildRecommendationsURL(limit: limit, market: market, seeds: seeds, targets: targets) else {
                completion([])
                return
            }

            // 4) Use the CURRENT USER'S token for one Spotify call
            SpotifyAuthManager.shared.getValidAccessToken { token in
                guard let token = token else {
                    print("Spotify token unavailable; returning empty recs.")
                    completion([])
                    return
                }
                self.performSpotifyGET(url: url, token: token) { json in
                    let tracks = self.parseRecommendations(json: json)
                    completion(tracks)
                }
            }
        }
    }

    // Fetch userInfo docs
    private func fetchStats(for uids: [String], completion: @escaping ([String: SpotifyStats]) -> Void) {
        var results: [String: SpotifyStats] = [:]
        let chunks = stride(from: 0, to: uids.count, by: 10).map { Array(uids[$0..<min($0+10, uids.count)]) } //chunks code to go 10 at a time
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

        g.notify(queue: .main) {
            completion(results)
        }
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
            let tempo = t["tempo"] as? Double
            let energy = t["energy"] as? Double
            return SpotifyTrack(id: id, name: name, artists: artists, tempo: tempo, energy: energy)
        }

        // topArtists
        let topArtistsRaw = stats["topArtists"] as? [[String: Any]] ?? []
        let topArtists: [SpotifyArtist] = topArtistsRaw.compactMap { a in
            guard let id = a["id"] as? String else { return nil }
            let name = (a["name"] as? String) ?? "(unknown)"
            let genres = (a["genres"] as? [String]) ?? []
            return SpotifyArtist(id: id, name: name, genres: genres)
        }

        // genres
        let genresRaw = stats["genres"] as? [[String: Any]] ?? []
        let genres: [SpotifyGenreWeight] = genresRaw.compactMap { g in
            guard let name = g["name"] as? String else { return nil }
            let weight = g["weight"] as? Double ?? 0.0
            return SpotifyGenreWeight(name: name.lowercased(), weight: max(0, weight))
        }

        // user-level averages
        let tempoAvg = stats["tempoAvg"] as? Double
        let energyAvg = stats["energyAvg"] as? Double

        return SpotifyStats(topTracks: topTracks, topArtists: topArtists, genres: genres, tempoAvg: tempoAvg, energyAvg: energyAvg)
    }

    // Important helper structs and functions for creating combined seeds

    private struct Seeds {
        var artistIDs: [String] = []   // Spotify artist IDs
        var trackIDs:  [String] = []   // Spotify track IDs
        var genres:    [String] = []   // (Optional) Spotify-allowed genre seeds
    }

    private struct Targets {
        var tempoAvg:  Double?
        var energyAvg: Double?
    }

    // Combine members' cached stats into at most 5 seeds total
    // Strategy: prefer 3 artists + 2 tracks (fall back if fewer available). We skip genre seeds by default to avoid invalid-genre errors.
    private func buildGroupSeeds(uidToStats: [String: SpotifyStats], maxTotalSeeds: Int) -> Seeds {
        var artistCounts: [String: Int] = [:]     // artistId -> #members with that artist in topArtists
        var trackCounts:  [String: Int] = [:]     // trackId  -> #members with that track in topTracks

        for (_, s) in uidToStats {
            // artists
            let artistIDs = s.topArtists.map { $0.id }
            for a in Set(artistIDs) { artistCounts[a, default: 0] += 1 }
            // tracks
            let trackIDs = s.topTracks.map { $0.id }
            for t in Set(trackIDs) { trackCounts[t, default: 0] += 1 }
        }

        let topArtistIDs = artistCounts.sorted { (a, b) in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.map { $0.key }

        let topTrackIDs = trackCounts.sorted { (a, b) in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.map { $0.key }

        var seeds = Seeds()
        let desiredArtists = min(3, maxTotalSeeds)
        let desiredTracks  = min(2, maxTotalSeeds - desiredArtists)

        seeds.artistIDs = Array(topArtistIDs.prefix(desiredArtists))
        seeds.trackIDs  = Array(topTrackIDs.prefix(desiredTracks))

        return seeds
    }

    private func buildTargetParams(uidToStats: [String: SpotifyStats]) -> Targets {
        var tempos: [Double] = []
        var energies: [Double] = []
        for (_, s) in uidToStats {
            if let t = s.tempoAvg { tempos.append(t) }
            if let e = s.energyAvg { energies.append(e) }
        }
        let tAvg = tempos.isEmpty ? nil : (tempos.reduce(0, +) / Double(tempos.count))
        let eAvg = energies.isEmpty ? nil : (energies.reduce(0, +) / Double(energies.count))
        return Targets(tempoAvg: tAvg, energyAvg: eAvg)
    }


    // Helper to build URL
    private func buildRecommendationsURL(limit: Int, market: String?, seeds: Seeds, targets: Targets) -> URL? {
        var comps = URLComponents(string: "https://api.spotify.com/v1/recommendations")
        var q: [URLQueryItem] = [ .init(name: "limit", value: String(limit)) ]
        if let market = market { q.append(.init(name: "market", value: market)) }

        if !seeds.artistIDs.isEmpty {
            q.append(.init(name: "seed_artists", value: seeds.artistIDs.joined(separator: ",")))
        }
        if !seeds.trackIDs.isEmpty {
            q.append(.init(name: "seed_tracks", value: seeds.trackIDs.joined(separator: ",")))
        }
        if !seeds.genres.isEmpty {
            q.append(.init(name: "seed_genres", value: seeds.genres.joined(separator: ",")))
        }

        if let tempo = targets.tempoAvg {
            q.append(.init(name: "target_tempo", value: String(format: "%.1f", tempo)))
        }
        if let energy = targets.energyAvg {
            let clamped = max(0.0, min(1.0, energy))
            q.append(.init(name: "target_energy", value: String(format: "%.2f", clamped)))
        }

        comps?.queryItems = q
        return comps?.url
    }

    private func performSpotifyGET(url: URL, token: String, completion: @escaping ([String: Any]) -> Void) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let json = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            DispatchQueue.main.async { completion(json) }
        }.resume()
    }

    private func parseRecommendations(json: [String: Any]) -> [Track] {
        guard let items = json["tracks"] as? [[String: Any]] else { return [] }
        return items.compactMap { t -> Track? in
            guard let id = t["id"] as? String else { return nil }
            let name = (t["name"] as? String) ?? "(unknown)"
            let duration = (t["duration_ms"] as? Int) ?? 0

            let artistNames = (t["artists"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
            let artistsString = artistNames.joined(separator: ", ")

            var imageURL: String? = nil
            if
                let album = t["album"] as? [String: Any],
                let images = album["images"] as? [[String: Any]],
                let first = images.first,
                let url = first["url"] as? String
            {
                imageURL = url
            }

            return Track(
                id: id,
                name: name,
                artists: artistsString,
                duration_ms: duration,
                albumArt: imageURL,
                image: nil
            )
        }
    }
}
