//
//  PostDetailViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/3/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

protocol ChangeCommentsPostDetail {
    func changeComments(postID: String, newComment: Comment)
}

class PostDetailViewController: UIViewController, UIScrollViewDelegate, ChangeCommentsPostDetail, UIGestureRecognizerDelegate {
    
    var contentView: UIContentView!
    @IBOutlet weak var captionTextView: UITextView!
    
    @IBOutlet weak var likeHeartButton: UIButton!
    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var songNameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var postImageView: UIImageView!
    @IBOutlet weak var likesCount: UIButton!
    @IBOutlet weak var commentCount: UIButton!
    @IBOutlet weak var ratingLabel: UILabel!
    var post: Post?
    var delegate: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        captionTextView.text = post?.caption
        let tempRating = String(post?.rating ?? 0)
        ratingLabel.text = String("\(tempRating)/5")
        commentCount.setTitle(String(post?.comments.count ?? 0), for: .normal)
        
        // likes button
        updateLikesUI()
        
        usernameLabel.text = post?.displayName
        songNameLabel.text = post?.trackObject.name
        artistNameLabel.text = post?.trackObject.artists
        view.backgroundColor = UIColor(red: 1.0, green: 0.9372549019607843, blue: 0.8980392156862745, alpha: 1.0)
        
        // image
        if let albumArtURL = post?.trackObject.albumArt, let url = URL(string: albumArtURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.postImageView.image = img
                }
            }.resume()
        }
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = self
        postImageView.addGestureRecognizer(doubleTap)
        postImageView.isUserInteractionEnabled = true
        
        view.backgroundColor = UIColor(red: 1.0, green: 0.9372549019607843, blue: 0.8980392156862745, alpha: 1.0)
        
        likesCount.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        commentCount.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
            ratingLabel.font = font
            likesCount.titleLabel?.font = font
            commentCount.titleLabel?.font = font
        }
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 18) {
            usernameLabel.font = font
        }
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 16) {
            songNameLabel.font = font
        }
        
        if let font = UIFont(name: "Poppins-Regular", size: 14) {
            artistNameLabel.font = font
            captionTextView.font = font
        }
        
        postImageView.layer.cornerRadius = 10
        postImageView.clipsToBounds = true
        postImageView.layer.shadowColor = UIColor.black.cgColor
        postImageView.layer.shadowOpacity = 0.05
        postImageView.layer.shadowOffset = CGSize(width: 0, height: 2)
        postImageView.layer.shadowRadius = 4
        
    }
    
    
    func updateLikesUI() {
        guard let post = post, let currentUID = Auth.auth().currentUser?.uid else { return }
        
        // Update likes count
        likesCount.setTitle("\(post.likes.count)", for: .normal)
        
        // Update heart icon
        let heartImage = post.likes.contains(currentUID) ? "heart.fill" : "heart"
        likeHeartButton.setImage(UIImage(systemName: heartImage), for: .normal)
        likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
    }
    
    @IBAction func handleDoubleTap(recognizer: UITapGestureRecognizer) {
        guard let post else {return}
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(post.postID)
        
        if let index = post.likes.firstIndex(of: currentUID) {
                post.likes.remove(at: index)
            } else {
                post.likes.append(currentUID)
            }
        
        updateLikesUI()
        
        postRef.updateData(["likes": post.likes]) { error in
                if let error = error {
                    print("Error updating likes: \(error.localizedDescription)")
                }
        }
    }
    
   
    @IBAction func heartButtonTapped(_ sender: Any) {
        guard let post else {return}
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(post.postID)
        
        if let index = post.likes.firstIndex(of: currentUID) {
                post.likes.remove(at: index)
            } else {
                post.likes.append(currentUID)
            }
        
        updateLikesUI()
        
        postRef.updateData(["likes": post.likes]) { error in
                if let error = error {
                    print("Error updating likes: \(error.localizedDescription)")
                }
        }
    }
    
    func changeComments(postID: String, newComment: Comment) {
        guard let post = post else { return }
            post.comments.append(newComment)
            commentCount.setTitle(String(post.comments.count), for: .normal)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "likesSegue",
           let destVC = segue.destination as? LikeViewController {
            destVC.likes = post?.likes ?? []
        } else if segue.identifier == "commentsSegue",
                  let destVC = segue.destination as? CommentsViewController {
            destVC.comments = post?.comments ?? []
            destVC.delegate = self
            destVC.postID = post?.postID ?? ""
        }
    }
    

}
