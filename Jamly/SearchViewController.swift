//
//  SearchViewController.swift
//  Jamly
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
   
    // MARK: - Outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var friendsButton: UIButton!
    @IBOutlet weak var addFriendButton: UIButton!
    @IBOutlet weak var displayPostTable: UITableView!
    @IBOutlet weak var noPostsLabel: UILabel!
   
    // MARK: - Properties
    private var postDocs: [Post] = []
    private var foundUserID: String?
    var user: User?
    private let db = Firestore.firestore()
    private var isAlreadyFriend = false
    var initialFriendUID: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
       
        applyJamThemeStyling()
        if let navBar = navigationController?.navigationBar {
            navBar.barTintColor = UIColor(hex: "#FFEFE5")
        }
       
        searchBar.delegate = self
        displayPostTable.dataSource = self
        displayPostTable.delegate = self
        displayPostTable.isScrollEnabled = true
        displayPostTable.rowHeight = UITableView.automaticDimension
        displayPostTable.estimatedRowHeight = 72
        displayPostTable.separatorStyle = .singleLine

        displayPostTable.backgroundColor = UIColor(hex: "#FFC1CC")

        let bgView = UIView()
        bgView.backgroundColor = UIColor(hex: "#FFC1CC")
        displayPostTable.backgroundView = bgView

        // Center the displayNameLabel programmatically
        displayNameLabel.translatesAutoresizingMaskIntoConstraints = false
        displayNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        displayNameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 100).isActive = true

        // Hide UI elements initially
        [displayNameLabel, displayPostTable, noPostsLabel].forEach { $0?.isHidden = true }
        friendsButton.isHidden = true
        addFriendButton.isHidden = true
        addFriendButton.isEnabled = false

        // Update the searchBar to prevent capitalizing the text
        if let textField = searchBar.searchTextField as UITextField? {
            textField.autocapitalizationType = .none
        }
       
        // If opened with a specific friend UID, load that user
        if let uid = initialFriendUID {
            loadUser(byUID: uid)
        }
    }
   
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start listening for posts if a user is found
        if foundUserID != nil {
            fetchPostsForUser()
        }
    }


    // MARK: - Styling
    private func applyJamThemeStyling() {
        view.backgroundColor = UIColor(hex: "#FFEFE5")
       
        displayNameLabel.textColor = UIColor(hex: "#3D1F28")
        displayNameLabel.font = UIFont(name: "Poppins-SemiBold", size: 26)
        displayNameLabel.textAlignment = .center // Center the displayNameLabel text

        styleButton(friendsButton, title: "Friends", bgColor: "#FFC1CC")
        styleButton(addFriendButton, title: "Add Friends", bgColor: "#FFC1CC")
    }

    private func styleButton(_ button: UIButton, title: String, bgColor: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor(hex: bgColor)
        config.baseForegroundColor = UIColor(hex: "#3D1F28")
        config.cornerStyle = .medium
        config.titleAlignment = .center
        button.configuration = config

        if let font = UIFont(name: "Poppins-SemiBold", size: 15) {
            button.titleLabel?.font = font
        }

        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
    }

    // MARK: - Load User Profile
    private func loadUser(byUID uid: String) {
        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }
            if let err = err {
                self.alert("Error", err.localizedDescription)
                return
            }
            guard let data = doc?.data() else {
                self.alert("Not found", "Could not load this user.")
                return
            }

            self.foundUserID = doc?.documentID
            self.user = User(
                displayName: data["displayName"] as? String ?? "",
                email: data["email"] as? String ?? "",
                mobileNumber: data["mobileNumber"] as? String ?? "",
                name: data["name"] as? String ?? "",
                friends: data["friends"] as? [String] ?? []
            )

            DispatchQueue.main.async {
                self.updateProfileUI()
                self.fetchPostsForUser()
            }
        }
    }

    // MARK: - Update Profile UI
    private func updateProfileUI() {
        guard let u = user else { return }
       
        displayNameLabel.text = u.displayName
        displayNameLabel.isHidden = false
        friendsButton.isHidden = false
        addFriendButton.isHidden = false
        displayPostTable.isHidden = false
        noPostsLabel.isHidden = true

        addFriendButton.isEnabled = false
        addFriendButton.setTitle("Add Friend", for: .normal)

        guard let currentUID = Auth.auth().currentUser?.uid else { return }

        // Disable add friend button if current user is already a friend or the same person
        if currentUID == foundUserID {
            addFriendButton.isEnabled = false
            addFriendButton.setTitle("This is You", for: .normal)
            return
        }

        db.collection("userInfo").document(currentUID).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            let friends = doc?.data()?["friends"] as? [String] ?? []
            let alreadyFriends = friends.contains(self.foundUserID ?? "")

            DispatchQueue.main.async {
                self.isAlreadyFriend = alreadyFriends
                if alreadyFriends {
                    self.addFriendButton.isEnabled = false
                    self.addFriendButton.setTitle("Already Friends", for: .normal)
                } else {
                    self.addFriendButton.isEnabled = true
                    self.addFriendButton.setTitle("Add Friend", for: .normal)
                }
            }
        }
    }

    // MARK: - Fetch Posts
    private func fetchPostsForUser() {
        guard let uid = foundUserID else { return }

        postDocs.removeAll()
        displayPostTable.reloadData()

        db.collection("posts").whereField("userID", isEqualTo: uid).getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("Error fetching posts: \(err)")
                return
            }

            for document in snap?.documents ?? [] {
                let data = document.data()
                if let rating = data["rating"] as? Int,
                   let caption = data["caption"] as? String,
                   let trackData = data["trackObject"] as? [String: Any] {
                    let track = Track(
                        id: trackData["id"] as? String ?? "",
                        name: trackData["name"] as? String ?? "Unknown Song",
                        artists: trackData["artists"] as? String ?? "Unknown Artist",
                        duration_ms: trackData["duration_ms"] as? Int ?? 0,
                        albumArt: trackData["albumArt"] as? String,
                        image: nil
                    )

                    let newPost = Post(
                        userID: uid,
                        displayName: self.user?.displayName ?? "Unknown User",
                        postID: document.documentID,
                        rating: rating,
                        likes: data["likes"] as? [String] ?? [],
                        caption: caption,
                        comments: (data["comments"] as? [[String: Any]])?.compactMap {
                            Comment(userID: $0["userID"] as? String ?? "", commentText: $0["commentText"] as? String ?? "")
                        } ?? [],
                        trackObject: track
                    )
                    self.postDocs.append(newPost)
                }
            }

            DispatchQueue.main.async {
                self.displayPostTable.reloadData()
                self.noPostsLabel.isHidden = !self.postDocs.isEmpty
                self.noPostsLabel.text = self.user?.displayName ?? "User" + " has no posts"
            }
        }
    }

    // MARK: - TableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postDocs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "postCell",
            for: indexPath
        ) as? PostThumbnailTableViewCell else {
            fatalError("Could not dequeue postCell")
        }

        let post = postDocs[indexPath.row]
        cell.songName.text = post.trackObject.name
        cell.songRating.text = "\(post.rating)/5"

        // Apply styling (same as ProfileViewController's table cell)
        cell.backgroundColor = UIColor(hex: "#FFC1CC")
        cell.layer.cornerRadius = 12
        cell.contentView.layer.cornerRadius = 12
        cell.layer.masksToBounds = false

        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOpacity = 0.10
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.shadowRadius = 4

        // Album Art Styling
        cell.albumPic.layer.cornerRadius = 10
        cell.albumPic.clipsToBounds = true
        cell.albumPic.layer.borderWidth = 2
        cell.albumPic.layer.borderColor = UIColor(hex: "#FFF8F3").cgColor
        cell.albumPic.layer.shadowOpacity = 0.05
        cell.albumPic.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.albumPic.layer.shadowRadius = 4

        // Load album image
        if let urlStr = post.trackObject.albumArt, let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if let visibleCell = tableView.cellForRow(at: indexPath) as? PostThumbnailTableViewCell {
                            visibleCell.albumPic.image = img
                        }
                    }
                }
            }.resume()
        }

        return cell
    }

    // MARK: - Alerts
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}

