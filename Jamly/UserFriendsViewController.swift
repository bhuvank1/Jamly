//
//  UserFriendsViewController.swift
//  Jamly
//
//  Created by Pant, Rohan on 11/6/25.
//

import UIKit

import UIKit
import FirebaseFirestore

class UserFriendsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    // Injected from SearchViewController
    var friendIDs: [String] = []

    private var rows: [FriendRow] = []

    struct FriendRow {
        let uid: String
        let displayName: String
        let email: String
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        fetchFriends()
    }

    private func fetchFriends() {
        guard !friendIDs.isEmpty else { return }
        let db = Firestore.firestore()
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
            self.rows = tmp.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            self.tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // In storyboard: Prototype cell with Style=Subtitle, Reuse Identifier="FriendCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath)
        let f = rows[indexPath.row]
        cell.textLabel?.text = f.displayName
        cell.detailTextLabel?.text = f.email
        return cell
    }

    // (optional) push a profile later
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
