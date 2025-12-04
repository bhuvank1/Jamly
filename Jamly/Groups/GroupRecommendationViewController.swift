//
//  GroupRecommendationViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/12/25.
//

import UIKit

final class GroupRecommendationViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    weak var delegate: SelectSongDelegate?
    var group: Group!
    
    @IBOutlet weak var recommendationTableView: UITableView!
    
    private var recommendations: [Track] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Song Reccomendations"
        
        recommendationTableView.dataSource = self
        recommendationTableView.delegate = self
        recommendationTableView.rowHeight = 64
        recommendationTableView.tableFooterView = UIView()
        
        // THEME
        let appBg = UIColor(hex: "#FFEFE5")
        let accent = UIColor(hex: "#FFC1CC")

        view.backgroundColor = appBg
        recommendationTableView.backgroundColor = appBg
        recommendationTableView.separatorColor = accent.withAlphaComponent(0.6)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRecommendations()
    }
    
    private func loadRecommendations() {
        guard let group = group else { return }
        print("🎧 loadRecommendations(): group=\(group.name), id=\(group.id)")
        
        SpotifyGroupManager.shared.generateLiveRecommendationsViaSpotify(for: group, limit: 20) { [weak self] tracks in
            guard let self = self else { return }
            print("recommendations received: \(tracks.count) tracks")
            DispatchQueue.main.async {
                self.recommendations = tracks
                self.recommendationTableView.reloadData()
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

        cell.accessoryType = .none

        // Placeholder first
        cell.imageView?.image = UIImage(systemName: "music.note")

        // Load album art (no caching); guard against reuse
        if let urlStr = track.albumArt, let url = URL(string: urlStr) {
            let expectedIndexPath = indexPath
            weak var weakCell = cell
            URLSession.shared.dataTask(with: url) { [weak tableView] data, _, _ in
                guard
                    let data = data,
                    let img = UIImage(data: data),
                    let tableView = tableView
                else { return }

                DispatchQueue.main.async {
                    if let cell = weakCell,
                       let currentIndexPath = tableView.indexPath(for: cell),
                       currentIndexPath == expectedIndexPath {
                        cell.imageView?.image = img
                        cell.setNeedsLayout()
                    }
                }
            }.resume()
        }
        
        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        let selected = UIView()
        selected.backgroundColor = UIColor(hex: "#FFC1CC").withAlphaComponent(0.25)
        cell.selectedBackgroundView = selected

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let t = recommendations[indexPath.row]
        print("Selected recommendation: \(t.name) by \(t.artists)")

        // “Return” the song to GroupDisplayViewController
        delegate?.didSelectSong(t)
        navigationController?.popViewController(animated: true)
    }
}
