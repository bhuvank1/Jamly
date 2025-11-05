//
//  ProfileViewController.swift
//  Jamly
//
//  Created by Rohan Pant on 10/17/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // Other profile UI
    @IBOutlet weak var followersCountButton: UIButton!
    @IBOutlet weak var followingCountButton: UIButton!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var userImage: UIImageView!



    private var postDocs: [QueryDocumentSnapshot] = []
    private var listener: ListenerRegistration?


    private let showOnlyCurrentUser = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let user = Auth.auth().currentUser else {
            print("User is presently not signed in.")
            return
        }
        usernameLabel.text = user.displayName

        displayPostTable.dataSource = self
        displayPostTable.delegate = self
        displayPostTable.isScrollEnabled = true
        displayPostTable.rowHeight = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72

        startListeningForPosts()
    }

    deinit { listener?.remove() }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    private func startListeningForPosts() {
        let db = Firestore.firestore()
        var query: Query = db.collection("posts")

        if showOnlyCurrentUser, let uid = Auth.auth().currentUser?.uid {
            query = query.whereField("userID", isEqualTo: uid)
        }


        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Failed to fetch posts: \(error.localizedDescription)")
                return
            }
            self.postDocs = snapshot?.documents ?? []
            self.displayPostTable.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        postDocs.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        // If you have a custom cell with your own labels, dequeue it here instead
        let cell = displayPostTable.dequeueReusableCell(withIdentifier: "postCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "postCell")

        let data = postDocs[indexPath.row].data()

        // Safely read fields from Firestore
        let caption = data["caption"] as? String ?? ""
        let rating = (data["rating"] as? Int) ?? (data["rating"] as? NSNumber)?.intValue ?? 0
        let likes  = (data["likes"]  as? Int) ?? (data["likes"]  as? NSNumber)?.intValue  ?? 0
        let music  = data["musicName"] as? String ?? ""

        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = caption
        cell.detailTextLabel?.text = "Rating: \(rating) • Likes: \(likes) • \(music)"

        return cell
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        displayPostTable.deselectRow(at: indexPath, animated: true)
    }
}
