import UIKit
import FirebaseAuth
import FirebaseFirestore

class SearchViewController: UIViewController, UISearchBarDelegate {

    @IBOutlet weak var searchBar: UISearchBar!

    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var mobileNumberLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var friendsButton: UIButton!   // “Friends (N)”
    @IBOutlet weak var addFriendButton: UIButton! // “Add Friend”

    private var foundUserID: String?   // Firestore docID (UID) of the currently shown user
    var user: User?                    // parsed user fields from Firestore

    private let db = Firestore.firestore()
    private var isAlreadyFriend = false

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        // Hide UI until a user is found
        [displayNameLabel, emailLabel, mobileNumberLabel, nameLabel].forEach { $0?.isHidden = true }
        friendsButton.isHidden = true
        addFriendButton.isHidden = true
        addFriendButton.isEnabled = false
    }

    // MARK: - Search
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.isEmpty else { return }
        searchUser(byDisplayName: text)
        searchBar.resignFirstResponder()
    }

    private func searchUser(byDisplayName displayName: String) {
        db.collection("userInfo")
            .whereField("displayName", isEqualTo: displayName)
            .limit(to: 1)
            .getDocuments { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err { self.alert("Error", err.localizedDescription); return }
                guard let doc = snap?.documents.first else {
                    self.alert("Not found", "No user with that display name.")
                    self.addFriendButton.isHidden = true
                    self.friendsButton.isHidden = true
                    return
                }

                self.foundUserID = doc.documentID
                let d = doc.data()
                let friends = d["friends"] as? [String] ?? []
                self.user = User(
                    displayName: d["displayName"] as? String ?? "",
                    email:       d["email"] as? String ?? "",
                    mobileNumber:d["mobileNumber"] as? String ?? "",
                    name:        d["name"] as? String ?? "",
                    friends:     friends
                )
                self.updateProfileUI()
            }
    }

    // Load a specific user by UID (used when returning from Friends list)
    private func loadUser(byUID uid: String) {
        db.collection("userInfo").document(uid).getDocument { [weak self] doc, err in
            guard let self = self else { return }
            if let err = err { self.alert("Error", err.localizedDescription); return }
            guard let doc = doc, let data = doc.data() else {
                self.alert("Not found", "Could not load this user.")
                return
            }
            let friends = data["friends"] as? [String] ?? []
            self.foundUserID = doc.documentID
            self.user = User(
                displayName: data["displayName"] as? String ?? "",
                email:       data["email"] as? String ?? "",
                mobileNumber:data["mobileNumber"] as? String ?? "",
                name:        data["name"] as? String ?? "",
                friends:     friends
            )
            DispatchQueue.main.async { self.updateProfileUI() }
        }
    }

    private func updateProfileUI() {
        guard let u = user else { return }
        displayNameLabel.text     = "Display Name: \(u.displayName)"
        emailLabel.text           = "Email: \(u.email)"
        mobileNumberLabel.text    = "Mobile: \(u.mobileNumber)"
        nameLabel.text            = "Name: \(u.name)"
        friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)

        [displayNameLabel, emailLabel, mobileNumberLabel, nameLabel].forEach { $0?.isHidden = false }
        friendsButton.isHidden = false
        addFriendButton.isHidden = false

        // Default state until we check friendship
        addFriendButton.isEnabled = false
        addFriendButton.setTitle("Add Friend", for: .normal)

        // Disable if this is me, or if already a friend
        guard let currentUID = Auth.auth().currentUser?.uid,
              let targetUID = self.foundUserID else { return }

        if currentUID == targetUID {
            self.isAlreadyFriend = true
            self.addFriendButton.isEnabled = false
            self.addFriendButton.setTitle("This is You", for: .normal)
            return
        }

        // Check if targetUID is already in my friends list
        db.collection("userInfo").document(currentUID).getDocument { [weak self] doc, _ in
            guard let self = self else { return }
            let mine = doc?.data()?["friends"] as? [String] ?? []
            let already = mine.contains(targetUID)
            DispatchQueue.main.async {
                self.isAlreadyFriend = already
                if already {
                    self.addFriendButton.isEnabled = false
                    self.addFriendButton.setTitle("Already Friends", for: .normal)
                } else {
                    self.addFriendButton.isEnabled = true
                    self.addFriendButton.setTitle("Add Friend", for: .normal)
                }
            }
        }
    }

    // MARK: - Add Friend (with race-safe re-check)
    @IBAction func addFriendButtonTapped(_ sender: UIButton) {
        guard let currentUID = Auth.auth().currentUser?.uid else {
            alert("Not signed in", "Please sign in first.")
            return
        }
        guard let friendUID = foundUserID else { return }
        if currentUID == friendUID {
            alert("Oops", "You can’t add yourself.")
            return
        }

        let myDoc = db.collection("userInfo").document(currentUID)
        let friendDoc = db.collection("userInfo").document(friendUID)

        // Re-check before writing to avoid duplicates/races
        myDoc.getDocument { [weak self] snapshot, err in
            guard let self = self else { return }
            if let err = err { self.alert("Error", err.localizedDescription); return }

            let mine = snapshot?.data()?["friends"] as? [String] ?? []
            if mine.contains(friendUID) {
                self.isAlreadyFriend = true
                self.addFriendButton.isEnabled = false
                self.addFriendButton.setTitle("Already Friends", for: .normal)
                self.alert("Already Friends", "You’ve already added this user.")
                return
            }

            // Add friend to my list (arrayUnion prevents duplicates at server)
            self.addFriendButton.isEnabled = false
            myDoc.updateData(["friends": FieldValue.arrayUnion([friendUID])]) { [weak self] err in
                guard let self = self else { return }
                if let err = err {
                    self.alert("Error", err.localizedDescription)
                    self.addFriendButton.isEnabled = true
                    return
                }

                // OPTIONAL: mutual add (leave as-is or remove per your product)
                friendDoc.updateData(["friends": FieldValue.arrayUnion([currentUID])]) { _ in }

                self.isAlreadyFriend = true
                self.addFriendButton.setTitle("Already Friends", for: .normal)
                self.addFriendButton.isEnabled = false

                // Update local count
                if var u = self.user, !u.friends.contains(friendUID) {
                    u.friends.append(friendUID)
                    self.user = u
                    self.friendsButton.setTitle("Friends (\(u.friends.count))", for: .normal)
                }
            }
        }
    }

    // MARK: - Friends list segue
    @IBAction func friendsButtonTapped(_ sender: UIButton) {
        guard let ids = user?.friends, !ids.isEmpty else {
            alert("No friends", "This user has no friends yet.")
            return
        }
        performSegue(withIdentifier: "showFriendsSegue", sender: ids)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "showFriendsSegue" else { return }
        let ids = (sender as? [String]) ?? []

        if let dest = segue.destination as? UserFriendsViewController {
            dest.friendIDs = ids
            dest.onSelectFriend = { [weak self] uid in
                guard let self = self else { return }
                self.searchBar.text = ""          // Clear search bar when returning
                self.loadUser(byUID: uid)
            }
        } else if let nav = segue.destination as? UINavigationController,
                  let dest = nav.topViewController as? UserFriendsViewController {
            dest.friendIDs = ids
            dest.onSelectFriend = { [weak self] uid in
                guard let self = self else { return }
                self.searchBar.text = ""          // Clear search bar when returning
                self.loadUser(byUID: uid)
            }
        }
    }

    // MARK: - Helpers
    private func alert(_ title: String, _ msg: String) {
        let ac = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
