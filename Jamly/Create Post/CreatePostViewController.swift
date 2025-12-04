//
//  CreatePostViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class CreatePostViewController: UIViewController, SelectSongDelegate {
    private var ratingModel = RatingModel()

    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var selectSongButton: UIButton!
    @IBOutlet weak var ratingContainer: UIView!
    @IBOutlet weak var ratingField: UITextField!
    
    @IBOutlet weak var captionField: UITextView!
    @IBOutlet weak var trackTitle: UILabel!
    @IBOutlet weak var trackImage: UIImageView!
    
    private var rating: Int = 0
    
    var track:Track?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Spread the Jam! 🍓"
        
        styleButton(postButton, title: "Spread the Jam! 🍓", bgColor: "#FFC1CC")
        styleButton(selectSongButton, title: "Choose your Track", bgColor: "#FFC1CC")

        setCaptionFieldStyling()
        view.backgroundColor = UIColor(hex: "#FFEFE5")
        
        // Track info
        trackTitle.textColor = UIColor(hex: "#3D1F28")
        if let font = UIFont(name: "Poppins-SemiBold", size: 17) {
            trackTitle.font = font
        }
        
        trackImage.layer.cornerRadius = 10
        trackImage.clipsToBounds = true
        trackImage.layer.borderWidth = 2
        trackImage.layer.borderColor = UIColor(hex: "#FFF8F3").cgColor
        trackImage.layer.shadowColor = UIColor.black.cgColor
        trackImage.layer.shadowOpacity = 0.05
        trackImage.layer.shadowOffset = CGSize(width: 0, height: 2)
        trackImage.layer.shadowRadius = 4
        
        setRatingView()
        applySelectedTrackToUI()
        // Do any additional setup after loading the view.
    }
    private func styleButton(_ button: UIButton, title: String, bgColor: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor(hex: bgColor)
        config.baseForegroundColor = UIColor(hex: "#3D1F28")
        config.cornerStyle = .medium
        config.titleAlignment = .center
        button.configuration = config
        
        // Set font
        if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
            button.titleLabel?.font = font
        }
        
        // Optional subtle shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
    }
    
    func setCaptionFieldStyling() {
        captionField.backgroundColor = UIColor(hex: "#FFF8F3")
        captionField.textColor = UIColor(hex: "#3D1F28")
        captionField.font = UIFont(name: "Inter-Regular", size: 16)
        captionField.layer.cornerRadius = 8
        captionField.layer.borderWidth = 1
        captionField.layer.borderColor = UIColor(hex: "#FFEFE5").cgColor
        captionField.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        captionField.isScrollEnabled = true      // Optional: true if text might exceed box
    }
    
    func setRatingView() {
        let ratingView = StarRatingView(model: ratingModel)
        
        let hostingController = UIHostingController(rootView: ratingView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        ratingContainer.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: ratingContainer.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: ratingContainer.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
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
        let rating = ratingModel.rating
            
        // Safely unwrap caption or default to empty string
        let caption = captionField.text ?? ""
        
        let post = Post(userID: user.uid, displayName: user.displayName ?? "", postID: postID, rating: rating, likes: [], caption: caption, comments: [], trackObject: selectedTrack)
        
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
            trackImage.tintColor = UIColor(hex: "#E983D8")
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
            trackImage.tintColor = UIColor(hex: "#E983D8")
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
