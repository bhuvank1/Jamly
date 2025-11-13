//
//  PostTableViewCell.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/6/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class PostTableViewCell: UITableViewCell {
    
    var listenLaterTrackIDs: Set<String> = [] // holds ID of track

    @IBOutlet weak var listenLaterButton: UIButton!
    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var commentsButton: UIButton!
    @IBOutlet weak var likesButton: UIButton!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var postImageView: UIImageView!
    
    @IBOutlet weak var mutualGroupsButton: UIButton!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var songNameLabel: UILabel!
    @IBOutlet weak var captionText: UITextView!
    var delegate: UIViewController?
    
    var post: Post? {
        didSet {
                
                // Add double tap gesture only once
                if postImageView.gestureRecognizers?.isEmpty ?? true {
                    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
                    doubleTap.numberOfTapsRequired = 2
                    doubleTap.cancelsTouchesInView = true
                    postImageView.addGestureRecognizer(doubleTap)
                    postImageView.isUserInteractionEnabled = true
                }
            
            setButtonState()
            }
    }
    
   
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        postImageView.isUserInteractionEnabled = true
        
        if postImageView.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) == false {
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
            doubleTap.numberOfTapsRequired = 2
            postImageView.addGestureRecognizer(doubleTap)
            
            // prevents tableView from being double tapped instead
            doubleTap.cancelsTouchesInView = true
        }
        
        selectionStyle = .none
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func commentsButtonTapped(_ sender: Any) {
        if let post = post {
            let otherVC = delegate as! ShowLikesComments
            otherVC.didTapCommentsButton(for: post)
        }
        
    }
    
    @IBAction func likesButtonTapped(_ sender: Any) {
        if let post = post {
            let otherVC = delegate as! ShowLikesComments
            otherVC.didTapLikesButton(for: post)
        }
    }
    
    @IBAction func handleDoubleTap(recognizer: UITapGestureRecognizer) {
        guard let post = post else { return }
        let otherVC = delegate as! ChangeLikesSocialFeed
        otherVC.changeLikes(for: post, cell: self)
    }
    
    // function that adds track in post to database and removes it if already exists
    @IBAction func listenLaterBtnPressed(_ sender: Any) {
        guard let user = Auth.auth().currentUser else {return}
        let db = Firestore.firestore()
        
        guard let track = post?.trackObject else {return}
        
        let trackID = track.id
        
        let trackRef = db.collection("ListenLaters").document(user.uid).collection("tracks").document(trackID)
        
        let otherVC = delegate as! ShowPopup
        
        trackRef.getDocument { document, error  in
            if let document = document, document.exists {
                DispatchQueue.main.async {
                    self.listenLaterButton.setTitle("+ 🎵", for: .normal)
                }
                trackRef.delete { _ in
                    otherVC.makePopup(popupTitle: "Deleted a track from Listen Later", popupMessage: "Successfully removed \(track.name) from your playlist!")
                    print("Deleting existing track from Listen Later.")}
            } else {
                trackRef.setData(track.toDictionary()) { error in
                    if let error = error {
                        print("Error adding track: \(error.localizedDescription)")
                    } else {
                        DispatchQueue.main.async {
                            self.listenLaterButton.setTitle("Added ✓", for: .normal)
                        }
                        otherVC.makePopup(popupTitle: "Added a track to your Listen Later", popupMessage: "Successfully added \(track.name) to your playlist!")
                    }
                }
            }
        }
    }
    
    // function to set the button state correctly as soon as screen loads
    private func setButtonState() {
        guard let user = Auth.auth().currentUser else {return}
        let db = Firestore.firestore()
        
        guard let track = post?.trackObject else {return}
        
        let trackID = track.id
        
        let trackRef = db.collection("ListenLaters").document(user.uid).collection("tracks").document(trackID)
       
        trackRef.getDocument { document, error  in
            DispatchQueue.main.async {
                if let document = document, document.exists {
                    self.listenLaterButton.setTitle("Added ✓", for: .normal)
                } else {
                    self.listenLaterButton.setTitle("+ 🎵", for: .normal)
                }
            }
        }
    }
    
    @IBAction func mutualGroupsButtonTapped(_ sender: Any) {
        if let post = post {
            let otherVC = delegate as! ShowMutualGroups
            otherVC.didTapMutualGroups(for: post)
        }
    }
}
