//
//  CommentsViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/4/25.
//

import UIKit
import FirebaseFirestore

class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let textCellIdentifier = "TextCell"
    @IBOutlet weak var commentsTableView: UITableView!
    var comments: [Comment] = []
    var commentsDisplay: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        commentsTableView.dataSource = self
        commentsTableView.delegate = self
        fetchDisplayNamesForComments()
    }
    
    func fetchDisplayNamesForComments() {
        let db = Firestore.firestore()
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
