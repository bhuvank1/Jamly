//
//  LikeViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/4/25.
//

import UIKit
import FirebaseFirestore

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
        
        cell.contentConfiguration = content
        return cell
    }
    
}
