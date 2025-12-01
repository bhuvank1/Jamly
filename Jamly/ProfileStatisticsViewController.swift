//
//  ProfileStatisticsViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/22/25.
//

import UIKit

class ProfileStatisticsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var typeSeg: UISegmentedControl!
    @IBOutlet weak var amountSeg: UISegmentedControl!
    
    @IBOutlet weak var tableView: UITableView!
    
    private var selectedType: QueryType = .genres
    private var selectedLimit: Int = 5
    
    private enum QueryType { case genres, artists, songs }
    private var currentType: QueryType {
        switch typeSeg.selectedSegmentIndex {
        case 0: return .genres
        case 1: return .artists
        default: return .songs
        }
    }
    
    private var currentLimit: Int {
        switch amountSeg.selectedSegmentIndex {
        case 0: return 5
        case 1: return 10
        default: return 100
        }
    }
    
    private var rows: [Track] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        
        // THEME
        let appBg = UIColor(hex: "#FFEFE5")
        let accent = UIColor(hex: "#FFC1CC")

        view.backgroundColor = appBg
        tableView.backgroundColor = appBg
        tableView.separatorColor = accent.withAlphaComponent(0.6)
        tableView.tableFooterView = UIView()

        // Segmented controls
        typeSeg.backgroundColor = appBg
        typeSeg.selectedSegmentTintColor = accent
        amountSeg.backgroundColor = appBg
        amountSeg.selectedSegmentTintColor = accent
        
        runQuery()
        
    }
        
    @IBAction func onTypeSegChanged(_ sender: Any) {
        switch typeSeg.selectedSegmentIndex {
            case 0: selectedType = .genres
            case 1: selectedType = .artists
            default: selectedType = .songs
        }
        runQuery()
    }
    
    @IBAction func onAmountSegChanged(_ sender: Any) {
        switch amountSeg.selectedSegmentIndex {
            case 0: selectedLimit = 5
            case 1: selectedLimit = 10
            default: selectedLimit = 100
        }
        runQuery()
    }
    
    //Helper function to run query for stats
    private func runQuery() {
        guard let url = makeQueryURL() else { return }
        makeAPICall(url: url) { [weak self] tracks in
            self?.rows = tracks
            DispatchQueue.main.async { self?.tableView.reloadData() }
        }
    }

    // Builds the Spotify endpoint URL
    private func makeQueryURL() -> URL? {
        let base: String
        switch selectedType {
        case .songs:
            base = "https://api.spotify.com/v1/me/top/tracks"
        case .artists, .genres:
            // genres reuses the artists endpoint (use the info on client side)
            base = "https://api.spotify.com/v1/me/top/artists"
        }
        
        let limit = min(selectedLimit, 50) // temporary limit until pagination is added

        var comps = URLComponents(string: base)
        comps?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "time_range", value: "medium_term")
        ]
        return comps?.url
    }
    
    //table functions copied from song search
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let t = rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "StatCell", for: indexPath)
        cell.selectionStyle = .none

        cell.textLabel?.font = .boldSystemFont(ofSize: 17)
        cell.detailTextLabel?.font = .systemFont(ofSize: 14)

        //change subtitle display based on what type is being displayed
        cell.textLabel?.text = "\(indexPath.row + 1). \(t.name)"
        if selectedType == .songs {
            cell.detailTextLabel?.text = "\(t.artists) · \(mmss(from: t.duration_ms))"
        } else if selectedType == .artists {
            cell.detailTextLabel?.text = t.artists
        } else {
            cell.detailTextLabel?.text = ""
        }

        if let img = t.image {
            cell.imageView?.image = img
            cell.setNeedsLayout()
        } else if let urlStr = t.albumArt, let url = URL(string: urlStr) {
            cell.imageView?.image = UIImage(systemName: "music.note")
            let rowIndex = indexPath.row
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    if rowIndex < self.rows.count {
                        self.rows[rowIndex].image = img
                    }
                    if let live = tableView.cellForRow(at: indexPath) {
                        live.imageView?.image = img
                        live.setNeedsLayout()
                    }
                }
            }.resume()
        } else {
            cell.imageView?.image = UIImage(systemName: "music.note")
            cell.setNeedsLayout()
        }
        
        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        let selected = UIView()
        selected.backgroundColor = UIColor(hex: "#FFC1CC").withAlphaComponent(0.25)
        cell.selectedBackgroundView = selected
        
        return cell
    }
    
    private func makeAPICall(url: URL, completion: @escaping ([Track]) -> Void) {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            guard let token = token else { completion([]); return }

            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { data, _, err in
                guard err == nil, let data = data else { completion([]); return }
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let items = json?["items"] as? [[String: Any]] ?? []
                    //items is an array of tracks (dictionaries)
                    
                    //secondary check to determine how to return results
                    //compact map is a library that loops over every element, $0 refers to the first arguement passed in. Use to loop through map and convert
                    switch self.selectedType {
                    case .songs:
                        let tracks = items.compactMap { self.trackFromTopTrackJSON($0) }
                        completion(tracks)

                    case .artists:
                        let artistsAsRows = items.compactMap { self.pseudoTrackFromArtistJSON($0) }
                        completion(artistsAsRows)

                    case .genres:
                        // Aggregate genres from top artists
                        var counts: [String: Int] = [:]
                        for artist in items {
                            for g in (artist["genres"] as? [String]) ?? [] {
                                counts[g, default: 0] += 1
                            }
                        }
                        // Sort by count then alphabetically
                        let sorted = counts.sorted { l, r in
                            if l.value == r.value { return l.key < r.key }
                            return l.value > r.value
                        }
                        let genreRows = sorted.prefix(self.selectedLimit).map {
                            self.pseudoTrackForGenre(name: $0.key, artistCount: $0.value)
                        }
                        completion(genreRows)
                    }
                } catch {
                    completion([])
                }
            }.resume()
        }
    }
    
    //chat GPT generated helpers to convert into tracks for display
    private func trackFromTopTrackJSON(_ dict: [String: Any]) -> Track? {
        guard
            let id = dict["id"] as? String,
            let name = dict["name"] as? String,
            let duration = dict["duration_ms"] as? Int
        else { return nil }

        // artist names
        let artistNames = (dict["artists"] as? [[String: Any]] ?? [])
            .compactMap { $0["name"] as? String }
            .joined(separator: ", ")

        var art: String? = nil
        if let album = dict["album"] as? [String: Any],
           let images = album["images"] as? [[String: Any]],
           let medium = images.dropFirst().first?["url"] as? String ?? images.first?["url"] as? String {
            art = medium
        }

        return Track(id: id, name: name, artists: artistNames, duration_ms: duration, albumArt: art)
    }

    private func pseudoTrackFromArtistJSON(_ dict: [String: Any]) -> Track? {
        guard
            let artistId = dict["id"] as? String,
            let name = dict["name"] as? String
        else { return nil }

        let genres = (dict["genres"] as? [String]) ?? []
        let subtitle = genres.isEmpty ? "Artist" : genres.prefix(3).joined(separator: " · ")

        var art: String? = nil
        if let images = dict["images"] as? [[String: Any]],
           let medium = images.dropFirst().first?["url"] as? String ?? images.first?["url"] as? String {
            art = medium
        }

        return Track(id: "artist:\(artistId)", name: name, artists: subtitle, duration_ms: 0, albumArt: art)
    }

    private func pseudoTrackForGenre(name: String, artistCount: Int) -> Track {
        let subtitle = "\(artistCount) artist" + (artistCount == 1 ? "" : "s")
        return Track(id: "genre:\(name)", name: name, artists: subtitle, duration_ms: 0, albumArt: nil)
    }
}

