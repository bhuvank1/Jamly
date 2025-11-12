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
//        loadRecommendations()
    }

    @IBAction func tempButton(_ sender: Any) {
        loadRecommendations()
    }
    
    private func loadRecommendations() {
        SpotifyGroupManager.shared.generateLiveRecommendationsViaSpotify(for: group, limit: 20) { [weak self] tracks in
            guard let self = self else { return }
            self.recommendations = tracks
            self.reccomendationTableView.reloadData()
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
}
