//
//  MyFriendsViewController.swift
//  Jamly
//
//  Created by Pant, Rohan on 11/21/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class MyFriendsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    private let db = Firestore.firestore()
    private var tmp: [FriendRow] = []

    private var selectedFriendUID: String?

    struct FriendRow {
        let uid: String
        let displayName: String
        let email: String
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        fetchMyFriends()
    }

    private func fetchMyFriends() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        db.collection("userInfo").document(currentUID).getDocument { snapshot, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            guard let data = snapshot?.data(),
                  let friendIDs = data["friends"] as? [String] else {
                print("No friends")
                return
            }
            self.tmp.removeAll()
            for uid in friendIDs {
                self.db.collection("userInfo").document(uid).getDocument { doc, error in
                    if let error = error {
                        print(error.localizedDescription)
                        return
                    }
                    guard let data = doc?.data() else { return }
                    let dn = data["displayName"] as? String ?? "(unknown)"
                    let em = data["email"] as? String ?? ""
                    self.tmp.append(FriendRow(uid: uid, displayName: dn, email: em))
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tmp.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "myFriendCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
        let f = tmp[indexPath.row]
        cell.textLabel?.text = f.displayName
        cell.detailTextLabel?.text = f.email
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let friend = tmp[indexPath.row]
        selectedFriendUID = friend.uid
        performSegue(withIdentifier: "showFriendInSearchFromMyFriends", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFriendInSearchFromMyFriends",
           let dest = segue.destination as? SearchViewController,
           let uid = selectedFriendUID {
            dest.initialFriendUID = uid
        }
    }
}
