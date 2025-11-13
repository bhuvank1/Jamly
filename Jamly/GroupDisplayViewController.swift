//
//  GroupDisplayViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/11/25.
//

import UIKit
import FirebaseFirestore

class GroupDisplayViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SelectSongDelegate {
    
    var group: Group!
    
    @IBOutlet weak var groupDescription: UILabel!
    @IBOutlet weak var playlistTableView: UITableView!
    
    private var playlist: [Track] = []
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = group?.name
        groupDescription.text = group?.description
        
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        groupDescription.text = group?.description
        loadGroupPlaylist()
    }
    
    func didSelectSong(_ track: Track) {
        let docRef = db.collection("groups").document(group.id)
        docRef.getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("didSelectSong getDocument error: \(err.localizedDescription)")
                return
            }
            guard let snap = snap, let updatedGroup = Group(doc: snap) else {
                print("didSelectSong: group doc missing or failed to unpack")
                return
            }

            // Build updated playlist with a simple anti dupe
            var newPlaylist = updatedGroup.playlist
            if !newPlaylist.contains(where: { $0.id == track.id }) {
                newPlaylist.append(track)
            } else {
                DispatchQueue.main.async {
                    self.group = updatedGroup
                    self.playlist = updatedGroup.playlist
                    self.playlistTableView.reloadData()
                }
                return
            }

            // Save back only the playlist field to avoid clobbering other fields
            let payload = newPlaylist.map { $0.toDictionary() }
            docRef.updateData(["playlist": payload]) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    print("didSelectSong updateData error: \(error.localizedDescription)")
                    return
                }
                // Reload from source of truth (or just update local state)
                DispatchQueue.main.async {
                    self.group = Group(doc: snap) ?? updatedGroup
                    self.playlist = newPlaylist
                    self.playlistTableView.reloadData()
                }
            }
        }
    }
    
    // Load playlist from Firestore and auto-unpack
    func loadGroupPlaylist() {
        let docRef = db.collection("groups").document(group.id)
        docRef.getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("loadGroupPlaylist error: \(err.localizedDescription)")
                DispatchQueue.main.async {
                    self.playlist = []
                    self.playlistTableView.reloadData()
                }
                return
            }
            guard let snap = snap, let unpacked = Group(doc: snap) else {
                DispatchQueue.main.async {
                    self.playlist = []
                    self.playlistTableView.reloadData()
                }
                return
            }
            DispatchQueue.main.async {
                self.group = unpacked
                self.playlist = unpacked.playlist
                self.playlistTableView.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        playlist.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let track = playlist[indexPath.row]
        
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
        
        // Load album art, guard against cell reuse
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
        let t = playlist[indexPath.row]
        print("Selected track: \(t.name) by \(t.artists)")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "groupSelectSong":
            if let dest = segue.destination as? SelectSongViewController {
                dest.delegate = self
            }
        case "groupRecommendSong":
            if let dest = segue.destination as? GroupRecommendationViewController {
                dest.delegate = self
                dest.group = self.group
            }
        case "showMembers":
            if let dest = segue.destination as? GroupMembersViewController {
                dest.group = group
            }
        default:
            break
        }
    }
    
}
