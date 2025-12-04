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
        
        commentsTableView.backgroundColor = .clear
        view.backgroundColor = UIColor(red: 1.0, green: 0.9372549019607843, blue: 0.8980392156862745, alpha: 1.0)
        addCommentButton.tintColor = UIColor(red: 0.9137254901960784, green: 0.5137254901960784, blue: 0.8470588235294118, alpha: 1.0)
        
        addCommentTextField.layer.borderWidth = 1.0
        addCommentTextField.layer.borderColor = UIColor(red: 0.23921568627450981, green: 0.12156862745098039, blue: 0.1568627450980392, alpha: 1.0).cgColor
        addCommentTextField.layer.cornerRadius = 8
        addCommentTextField.clipsToBounds = true
        navigationItem.title = "Comments"

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
                        
                        if let otherVC = self.delegate as? ChangeCommentsSocialFeed {
                            otherVC.changeComments(postID: self.postID, newComment: newComment)
                        } else if let otherVC = self.delegate as? ChangeCommentsPostDetail {
                            otherVC.changeComments(postID: self.postID, newComment: newComment)
                        }
                        
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
        
        // font
        if let font = UIFont(name: "Poppins-Regular", size: 14) {
            cell.detailTextLabel?.font = font
        }
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 16) {
            cell.textLabel?.font = font
        }
        
        cell.backgroundColor = .clear
        return cell
    }
    
    

}
