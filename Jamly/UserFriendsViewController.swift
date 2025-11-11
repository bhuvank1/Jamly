//
//  UserFriendsViewController.swift
//  Jamly
//
//  Created by Pant, Rohan on 11/6/25.
//

import UIKit
import FirebaseFirestore

class UserFriendsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    // Injected from SearchViewController
    var friendIDs: [String] = []

    // Callback to send the selected friend's UID back to SearchViewController
    var onSelectFriend: ((String) -> Void)?

    private let db = Firestore.firestore()
    private var rows: [FriendRow] = []

    // Keep UID internal; never display it
    struct FriendRow {
        let uid: String
        let displayName: String
        let email: String
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        assert(tableView != nil, "tableView outlet not connected")
        tableView.dataSource = self
        tableView.delegate = self
        fetchFriends()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        fetchFriends()
    }

    private func fetchFriends() {
        guard !friendIDs.isEmpty else { return }

        let group = DispatchGroup()
        var tmp: [FriendRow] = []

        friendIDs.forEach { uid in
            group.enter()
            db.collection("userInfo").document(uid).getDocument { doc, _ in
                defer { group.leave() }
                guard let data = doc?.data() else { return }
                let dn = data["displayName"] as? String ?? "(unknown)"
                let em = data["email"] as? String ?? ""
                tmp.append(FriendRow(uid: uid, displayName: dn, email: em))
            }
        }

        group.notify(queue: .main) {
            self.rows = tmp.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            self.tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "FriendCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        let f = rows[indexPath.row]
        cell.textLabel?.text = f.displayName
        cell.detailTextLabel?.text = f.email
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let friend = rows[indexPath.row]
        onSelectFriend?(friend.uid)  // Send UID back so SearchVC can load the profile
        if let nav = navigationController {
            nav.popViewController(animated: true) // Go back to SearchViewController
        } else {
            dismiss(animated: true)
        }
    }
}

