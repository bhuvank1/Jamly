//
//  UserFriendsViewController.swift
//  Jamly
//
//  Created by Pant, Rohan on 11/6/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class UserFriendsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    // Injected from SearchViewController
    var friendIDs: [String] = []

    // Callback to send the selected friend's UID back to SearchViewController
    var onSelectFriend: ((String) -> Void)?

    private let db = Firestore.firestore()
    private var tmp: [FriendRow] = []

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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        print("I am in view did appear")
        fetchFriends()
    }

    private func fetchFriends() {
        if (friendIDs.isEmpty) {
            retrieveFriends()
            return
        }

        tmp.removeAll()

        for uid in friendIDs {
            //group.enter()
            db.collection("userInfo").document(uid).getDocument { (doc, error) in
                if let error = error {
                    print("Error fetching document.")
                    return
                }
                guard let data = doc?.data() else { return }
                let dn = data["displayName"] as? String ?? "(unknown)"
                print("display name:", dn)
                let em = data["email"] as? String ?? ""
                self.tmp.append(FriendRow(uid: uid, displayName: dn, email: em))
                self.tableView.reloadData()
            }
            
        }
        
        func retrieveFriends() {
            guard let currentUID = Auth.auth().currentUser?.uid else { return }
            db.collection("userInfo").document(currentUID).getDocument { querySnapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                guard let data = querySnapshot?.data(),
                      let friendIDs = data["friends"] as? [String], !friendIDs.isEmpty else {
                    print("No friends found")
                    return
                }
                for uid in friendIDs {
                    self.db.collection("userInfo").document(uid).getDocument { (doc, error) in
                        if let error = error {
                            print("Error fetching document.")
                            return
                        }
                        guard let data = doc?.data() else { return }
                        let dn = data["displayName"] as? String ?? "(unknown)"
                        print("display name:", dn)
                        let em = data["email"] as? String ?? ""
                        self.tmp.append(FriendRow(uid: uid, displayName: dn, email: em))
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print(tmp.count)
        return tmp.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseID = "FriendCell"
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
        onSelectFriend?(friend.uid)  // Send UID back so SearchVC can load the profile
        if let nav = navigationController {
            nav.popViewController(animated: true) // Go back to SearchViewController
        } else {
            dismiss(animated: true)
        }
    }
}

