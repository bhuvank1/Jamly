//
//  SearchSongViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/20/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchSongViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    
    private let db = Firestore.firestore()

    @IBOutlet weak var songTableView: UITableView!
    
    private var results: [Track] = []
    private let searchController = UISearchController(searchResultsController: nil)
    private var pendingWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "BackgroundAppColor")!
        title = "Search Song"
        
        songTableView.dataSource = self
        songTableView.delegate = self
        songTableView.backgroundColor = .clear

        songTableView.dataSource = self
        songTableView.delegate = self
        
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false  // important when no nav bar

        // Put the search bar in the table header
        let sb = searchController.searchBar
        sb.searchBarStyle = .minimal
        sb.placeholder = "Search songs or artists"
        sb.sizeToFit()
        
        songTableView.tableHeaderView = sb
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        // Simple delay wait 250ms
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            SpotifySearchApi.shared.searchTracks(query: text, limit: 15) { result in
                switch result {
                case .success(let tracks):
                    DispatchQueue.main.async {
                        self.results = tracks
                        self.songTableView.reloadData()
                    }
                case .failure:
                    DispatchQueue.main.async {
                        self.results = []
                        self.songTableView.reloadData()
                    }
                }
            }
        }
        pendingWorkItem = work  // Sets up delay so it isn't constantly making calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // Table setup
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let content = results[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath)
        
        // Font setup
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)

        cell.textLabel?.text = content.name
        cell.detailTextLabel?.text = "\(content.artists) · \(mmss(from: content.duration_ms))"
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.numberOfLines = 1
        
        // Image setup and check
        if let cachedImage = content.image {
            cell.imageView?.image = cachedImage
            cell.setNeedsLayout()
        } else {
            cell.imageView?.image = UIImage(systemName: "music.note") // placeholder
            
            if let urlStr = content.albumArt, let url = URL(string: urlStr) {
                URLSession.shared.dataTask(with: url) { data, _, _ in // Create network request
                    guard let data = data, let img = UIImage(data: data) else { return }

                    DispatchQueue.main.async {
                        // Store the image back in the array
                        self.results[indexPath.row].image = img

                        // Updating the cell for this indexPath
                        cell.imageView?.image = img
                        cell.setNeedsLayout()
                    }
                }.resume()
            }
            
            cell.setNeedsLayout()
        }
        
        cell.backgroundColor = UIColor(named: "BackgroundAppColor")!
        let selected = UIView()
        selected.backgroundColor = UIColor(named: "BackgroundAppColor")!.withAlphaComponent(0.25)
        cell.selectedBackgroundView = selected

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let track = results[indexPath.row]
        print("(Search Song) Selected \(track.name) by \(track.artists)")

        // Check if already saved, then branch to alert
        isInListenLater(track) { [weak self] exists in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if exists {
                    self.presentAlreadyAddedAlert(for: track)
                } else {
                    self.presentAddConfirmAlert(for: track)
                }
            }
        }
    }
    
    private func listenLaterDocRef(for uid: String, trackID: String) -> DocumentReference {
        db.collection("ListenLaters").document(uid).collection("tracks").document(trackID)
    }

    private func isInListenLater(_ track: Track, completion: @escaping (Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { completion(false); return }
        listenLaterDocRef(for: uid, trackID: track.id).getDocument { snap, _ in
            completion(snap?.exists == true)
        }
    }

    private func addToListenLater(_ track: Track, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let payload: [String: Any] = [
            "id": track.id,
            "name": track.name,
            "artists": track.artists,
            "duration_ms": track.duration_ms,
            "albumArt": track.albumArt ?? "",
            "addedAt": Timestamp(date: Date())
        ]
        listenLaterDocRef(for: uid, trackID: track.id).setData(payload) { err in
            if let err = err { completion(.failure(err)) }
            else { completion(.success(())) }
        }
    }

    private func presentAlreadyAddedAlert(for track: Track) {
        let ac = UIAlertController(
            title: "Already in Listen Later",
            message: "“\(track.name)” by \(track.artists) is already saved.",
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    private func presentAddConfirmAlert(for track: Track) {
        let ac = UIAlertController(
            title: "Add to Listen Later?",
            message: "Save “\(track.name)” by \(track.artists) to your Listen Later.",
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        ac.addAction(UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.addToListenLater(track) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        let done = UIAlertController(
                            title: "Saved",
                            message: "Added to Listen Later.",
                            preferredStyle: .alert
                        )
                        done.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(done, animated: true)
                    case .failure(let err):
                        let fail = UIAlertController(
                            title: "Error",
                            message: "Couldn’t save track: \(err.localizedDescription)",
                            preferredStyle: .alert
                        )
                        fail.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(fail, animated: true)
                    }
                }
            }
        }))
        present(ac, animated: true)
    }
    
    private func mmss(from milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
}
