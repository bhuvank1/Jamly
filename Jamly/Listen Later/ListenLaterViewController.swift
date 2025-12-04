//
//  ListenLaterViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ListenLaterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var playlist: [Track] = []
    let db = Firestore.firestore()

    @IBOutlet weak var playlistTableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Listen Later"
        playlistTableView.dataSource = self
        playlistTableView.delegate = self
        playlistTableView.backgroundColor = .clear
        
        view.backgroundColor = UIColor(hex: "#FFEFE5")
        
        reloadView()
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlist.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = playlistTableView.dequeueReusableCell(withIdentifier: "PlaylistTextCell", for: indexPath) as? ListenLaterTableViewCell else {
            fatalError("Could not deqeue cell")
        }
        
        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        
        let track = playlist[indexPath.row]
        cell.artistNameLabel.text = track.artists
        cell.trackNameLabel.text = track.name
        
        // image
        if let urlStr = track.albumArt, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    // Only set the image if the cell is still displaying this row
                    if let visibleCell = self.playlistTableView.cellForRow(at: indexPath) as? ListenLaterTableViewCell {
                        visibleCell.trackImage.image = img
                    }
                }
            }.resume()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete {
            guard let user = Auth.auth().currentUser else {return}
            let track = playlist[indexPath.row]
            let trackID = track.id
            let trackRef = db.collection("ListenLaters").document(user.uid).collection("tracks").document(trackID)
            
            trackRef.delete { error in
                if let error = error {
                    print("Error deleting track: \(error)")
                } else {
                    print("Track deleted successfully")
                    self.playlist.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
        }
    }
    
    private func reloadView() {
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("ListenLaters").document(user.uid).collection("tracks").getDocuments { querySnapshot, error in
            if let error = error {
                print("Error fetching tracks: \(error.localizedDescription)")
                return
            }
            
            self.playlist.removeAll()
            
            guard let documents = querySnapshot?.documents else {return}
            
            for document in documents {
                let data = document.data()
                
                guard
                    let albumArt = data["albumArt"] as? String,
                    let artists = data["artists"] as? String,
                    let duration_ms = data["duration_ms"] as? Int,
                    let id = data["id"] as? String,
                    let name = data["name"] as? String
                else { return }
                
                let newTrack = Track(id: id, name: name, artists: artists, duration_ms: duration_ms, albumArt: albumArt)
                
                self.playlist.append(newTrack)
            }
            self.playlistTableView.reloadData()
        }
        
    }

}
