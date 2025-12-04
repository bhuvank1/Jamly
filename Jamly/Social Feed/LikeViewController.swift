//
//  LikeViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/4/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class LikeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var likesTableView: UITableView!
    let textCellIdentifier = "TextCell"
    var likes: [String] = []
    var likeDisplayNames: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        likesTableView.dataSource = self
        likesTableView.delegate = self
        fetchUsernamesForLikes()
        
        likesTableView.backgroundColor = .clear
        view.backgroundColor = UIColor(red: 1.0, green: 0.9372549019607843, blue: 0.8980392156862745, alpha: 1.0)
        navigationItem.title = "Likes"
    }
    
    func fetchUsernamesForLikes() {
        let db = Firestore.firestore()
        print(likes)
        
        for uid in likes {
            db.collection("userInfo").document(uid).getDocument {
                (snapshot, err) in
                if let err = err {
                    print("Error fetching display name for \(uid): \(err)")
                } else {
                    if let data = snapshot?.data(),
                       let displayName = data["displayName"] as? String {
                        self.likeDisplayNames.append(displayName)
                    }
                    self.likesTableView.reloadData()
                }
            }
        }
    }
    
    // changing likes in social feed
    func changeLikes(for post: Post, cell: PostTableViewCell) {
        print("HERE IN CHANGE LIKES")
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        let postRef = db.collection("posts").document(post.postID)
        var updatedLikes = post.likes
        
        if let index = updatedLikes.firstIndex(of: currentUID) {
                updatedLikes.remove(at: index)
            } else {
                updatedLikes.append(currentUID)
            }
        
        postRef.updateData(["likes": updatedLikes]) { error in
            if let error = error {
                print("Error updating likes: \(error.localizedDescription)")
                return
            }
            post.likes = updatedLikes
            
            DispatchQueue.main.async {
                self.likesTableView.reloadData()
                 cell.likesButton.setTitle(String(post.likes.count), for: .normal)
                
                if post.likes.contains(currentUID) {
                   cell.likeHeartButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
                    cell.likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
                   } else {
                    cell.likeHeartButton.setImage(UIImage(systemName: "heart"), for: .normal)
                    cell.likeHeartButton.tintColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0)
                   }
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return likeDisplayNames.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        likesTableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: textCellIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = likeDisplayNames[indexPath.row]
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 16) {
            content.textProperties.font = font
        }
        
        cell.backgroundColor = .clear
        
        cell.contentConfiguration = content
        return cell
    }
    
}
