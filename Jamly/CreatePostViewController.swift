//
//  CreatePostViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreatePostViewController: UIViewController, SelectSongDelegate {
    

    @IBOutlet weak var captionField: UITextField!
    @IBOutlet weak var ratingField: UITextField!
    
    @IBOutlet weak var trackTitle: UILabel!
    @IBOutlet weak var trackImage: UIImageView!
    
    var track:Track?

    override func viewDidLoad() {
        super.viewDidLoad()
        applySelectedTrackToUI()
        // Do any additional setup after loading the view.
    }
    
    func didSelectSong(_ track: Track) {
        self.track = track;
        applySelectedTrackToUI()
    }
    
    
    let db = Firestore.firestore()
    
    @IBAction func postButtonPressed(_ sender: Any) {
        guard let user = Auth.auth().currentUser else { return }
        
        // Ensure track is selected
            guard let selectedTrack = track else {
                print("No track selected. Cannot create post.")
                // Optionally show an alert to the user
                let alert = UIAlertController(title: "Error", message: "Please select a track before posting.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        
        // generating postID
        let postRef = db.collection("posts").document()
        let postID = postRef.documentID
        
        // Safely unwrap rating or default to 1
        let rating = Int(ratingField.text ?? "") ?? 1
            
        // Safely unwrap caption or default to empty string
        let caption = captionField.text ?? ""
        
        let post = Post(userID: user.uid, postID: postID, rating: rating, likes: [], caption: caption, comments: [], trackObject: selectedTrack.toDictionary())
        
        postRef.setData(post.toDictionary()) { error in
            if let error = error {
                print("Error adding post \(error)")
            } else {
                self.dismiss(animated: true)
                // go back to home once user creates the post
                self.tabBarController?.selectedIndex = 0
            }
        }
    }
    
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
    
    private func applySelectedTrackToUI() {
        guard let t = track else {
            trackTitle.text = "No song selected"
            trackImage.image = UIImage(systemName: "music.note")
            return
        }
        trackTitle.text = t.name

        if let img = t.image {
            trackImage.image = img
        } else if let urlStr = t.albumArt, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    // optional cache
                    self.track?.image = img
                    self.trackImage.image = img
                }
            }.resume()
        } else {
            trackImage.image = UIImage(systemName: "music.note")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSelectSong" {
            if let vc = segue.destination as? SelectSongViewController {
                vc.delegate = self
            } else if let nav = segue.destination as? UINavigationController, //fallback if the vc is in a nav controller
                      let vc = nav.topViewController as? SelectSongViewController {
                vc.delegate = self
            }
        }
    }
}
