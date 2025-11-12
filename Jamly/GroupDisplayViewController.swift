//
//  GroupDisplayViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/11/25.
//

import UIKit

class GroupDisplayViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var group: Group!

    @IBOutlet weak var groupDescription: UILabel!
    @IBOutlet weak var reccomendationTableView: UITableView!

    private var recommendations: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = group?.name
        groupDescription.text = group?.description

        reccomendationTableView.dataSource = self
        reccomendationTableView.delegate = self
        reccomendationTableView.rowHeight = 64
        reccomendationTableView.tableFooterView = UIView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        groupDescription.text = group?.description
        loadRecommendations()
    }

    private func loadRecommendations() {
        print("🎧 loadRecommendations(): group=\(group?.name ?? "(nil)"), id=\(group?.id ?? "(nil)")")
        SpotifyGroupManager.shared.generateLiveRecommendationsViaSpotify(for: group, limit: 20) { [weak self] tracks in
            guard let self = self else { return }
            print("recommendations received: \(tracks.count) tracks")
            
            DispatchQueue.main.async {
                self.recommendations = tracks
                self.reccomendationTableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recommendations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let track = recommendations[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "TrackCell")

        // Title
        cell.textLabel?.text = track.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cell.textLabel?.numberOfLines = 1

        // Subtitle: artists • mm:ss
        let duration = mmss(from: track.duration_ms)
        cell.detailTextLabel?.text = "\(track.artists) • \(duration)"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 1

        cell.accessoryType = .disclosureIndicator

        // Placeholder first
        cell.imageView?.image = UIImage(systemName: "music.note")

        // Load album art (no caching); guard against cell reuse
        if let urlStr = track.albumArt, let url = URL(string: urlStr) {
            // capture a weak reference to the cell and the expected indexPath
            let expectedIndexPath = indexPath
            weak var weakCell = cell
            URLSession.shared.dataTask(with: url) { [weak tableView] data, _, _ in
                guard
                    let data = data,
                    let img = UIImage(data: data),
                    let tableView = tableView
                else { return }

                DispatchQueue.main.async {
                    // make sure the cell is still showing the same row
                    if let currentIndexPath = tableView.indexPath(for: weakCell ?? UITableViewCell()),
                       currentIndexPath == expectedIndexPath
                    {
                        weakCell?.imageView?.image = img
                        weakCell?.setNeedsLayout()
                    }
                }
            }.resume()
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        //temporarily just print, in the future group playlist?
        let t = recommendations[indexPath.row]
        print("Selected track: \(t.name) by \(t.artists)")
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMembers",
           let dest = segue.destination as? GroupMembersViewController {
            dest.group = group
        }
    }
    
    func runSpotifyDebugProbes() {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            guard let token = token else {
                print("🛑 No valid Spotify token available.")
                return
            }

            print("🎧 Starting Spotify debug probes...")
            print("Token preview: \(token)...")

            // 1️⃣ Test /me
            let meURL = URL(string: "https://api.spotify.com/v1/me")!
            var meReq = URLRequest(url: meURL)
            meReq.httpMethod = "GET"
            meReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            meReq.setValue("application/json", forHTTPHeaderField: "Accept")
            meReq.setValue("Jamly/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

            URLSession.shared.dataTask(with: meReq) { data, resp, _ in
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                print("👤 /me -> HTTP \(status)")
                if let data = data, let body = String(data: data, encoding: .utf8) {
                    print("👤 /me body preview:", body.prefix(300))
                }

                // 2️⃣ Test known-good recommendations
                let goodURL = URL(string: "https://api.spotify.com/v1/recommendations?limit=5&seed_tracks=4NHQUGzhtTLFvgF5SZesLK&market=US")!
                var goodReq = URLRequest(url: goodURL)
                goodReq.httpMethod = "GET"
                goodReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                goodReq.setValue("application/json", forHTTPHeaderField: "Accept")
                goodReq.setValue("Jamly/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

                URLSession.shared.dataTask(with: goodReq) { data, resp, _ in
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                    print("🧪 known-good /recommendations -> HTTP \(status)")
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        print("🧪 known-good body preview:", body.prefix(300))
                    }

                    // 3️⃣ Test single-artist (Drake) recommendations
                    let oneArtistURL = URL(string: "https://api.spotify.com/v1/recommendations?limit=5&seed_artists=3TVXtAsR1Inumwj472S9r4&market=US")!
                    var artistReq = URLRequest(url: oneArtistURL)
                    artistReq.httpMethod = "GET"
                    artistReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    artistReq.setValue("application/json", forHTTPHeaderField: "Accept")
                    artistReq.setValue("Jamly/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

                    URLSession.shared.dataTask(with: artistReq) { data, resp, _ in
                        let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                        print("🎤 1-artist /recommendations -> HTTP \(status)")
                        if let data = data, let body = String(data: data, encoding: .utf8) {
                            print("🎤 1-artist body preview:", body.prefix(300))
                        }
                        print("✅ All debug probes complete.")
                    }.resume()
                }.resume()
            }.resume()
        }
        probeGenreSeeds()
        probeSingleGenre()
    }
    
    func probeGenreSeeds() {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            guard let token = token else { print("No token"); return }
            let url = URL(string: "https://api.spotify.com/v1/recommendations/available-genre-seeds")!
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                print("🎯 /available-genre-seeds -> HTTP \(code)")
                if let d = data { print(String(data: d, encoding: .utf8) ?? "") }
            }.resume()
        }
    }

    func probeSingleGenre() {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            guard let token = token else { print("No token"); return }
            let url = URL(string: "https://api.spotify.com/v1/recommendations?limit=5&seed_genres=pop&market=US")!
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                print("🎯 /recommendations (genre=pop) -> HTTP \(code)")
                if let d = data { print(String(data: d, encoding: .utf8) ?? "") }
            }.resume()
        }
    }

}
