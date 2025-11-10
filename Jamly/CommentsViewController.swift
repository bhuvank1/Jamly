//
//  CommentsViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/4/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let textCellIdentifier = "TextCell"
    @IBOutlet weak var commentsTableView: UITableView!
    var comments: [Comment] = []
    var commentsDisplay: [String] = []
    var postID = ""
    var delegate: UIViewController?
    
    @IBOutlet weak var addCommentButton: UIButton!
    @IBOutlet weak var addCommentTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        commentsTableView.dataSource = self
        commentsTableView.delegate = self
        fetchDisplayNamesForComments()
    }
    
    @IBAction func addCommentButtonTapped(_ sender: Any) {
        let commentText = addCommentTextField.text!
        guard let user = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(postID)
        postRef.getDocument { querySnapshot, error in
            if let error = error {
                print("Error fetching post: \(error.localizedDescription)")
            } else {
                var currentComments = querySnapshot?.data()?["comments"] as? [[String: Any]] ?? []
                let newCommentDict: [String: Any] = ["userID": user.uid, "commentText": commentText]
                 currentComments.append(newCommentDict)
                
                postRef.updateData(["comments": currentComments]) { error in
                    if let error = error {
                        print("Error updating comments: \(error.localizedDescription)")
                    } else {
                        let newComment = Comment(userID: user.uid, commentText: commentText)
                        self.comments.append(newComment)
                        self.commentsDisplay.append("\(user.displayName ?? ""): \(commentText)")
                        self.commentsTableView.reloadData()
                        self.addCommentTextField.text = ""
                        
                        let otherVC = self.delegate as! ChangeComments
                        otherVC.changeComments(postID: self.postID, newComment: newComment)
                    }
                }
                
            }
            
        }
        
        
        
    }
    
    func fetchDisplayNamesForComments() {
        let db = Firestore.firestore()
        print(comments.count)
        for comment in comments {
            db.collection("userInfo").document(comment.userID).getDocument { snapshot, err in
                if let err = err {
                    print("Error fetching display name for \(comment.userID): \(err)")
                } else {
                    if let data = snapshot?.data(),
                        let displayName = data["displayName"] as? String {
                        let formatted = "\(displayName): \(comment.commentText)"
                        self.commentsDisplay.append(formatted)
                    }
                    self.commentsTableView.reloadData()
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       // print(commentsDisplay.count)
        return commentsDisplay.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: textCellIdentifier) ??
        UITableViewCell(style: .subtitle, reuseIdentifier: textCellIdentifier)
        
        //var content = cell.defaultContentConfiguration()
        let commentData = commentsDisplay[indexPath.row]
        
        let parts = commentData.split(separator: ":", maxSplits: 1).map { String($0) }
        if (parts.count == 2) {
            cell.textLabel?.text = parts[0].trimmingCharacters(in: .whitespaces)
            cell.detailTextLabel?.text = parts[1].trimmingCharacters(in: .whitespaces)
        }
        
        //cell.contentConfiguration = content
        return cell
    }
    
    

}
