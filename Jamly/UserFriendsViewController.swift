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

    var friendIDs: [String] = []
    var selectedFriendUID: String?

    private let db = Firestore.firestore()
    private var tmp: [FriendRow] = []

    struct FriendRow {
        let uid: String
        let displayName: String
        let email: String
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyJamThemeStyling()

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchFriends()
    }

    private func fetchFriends() {
        if friendIDs.isEmpty {
            retrieveFriends()
            return
        }

        tmp.removeAll()

        for uid in friendIDs {
            db.collection("userInfo").document(uid).getDocument { (doc, error) in
                if let error = error {
                    print("Error fetching document: \(error.localizedDescription)")
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

    private func retrieveFriends() {
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
            self.tmp.removeAll()
            for uid in friendIDs {
                self.db.collection("userInfo").document(uid).getDocument { (doc, error) in
                    if let error = error {
                        print("Error fetching document: \(error.localizedDescription)")
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

    // MARK: - Styling
    private func applyJamThemeStyling() {
        view.backgroundColor = UIColor(named: "BackgroundAppColor")!

        tableView.backgroundColor = UIColor(named: "BackgroundAppColor")!
        let bgView = UIView()
        bgView.backgroundColor = UIColor(named: "BackgroundAppColor")!
        tableView.backgroundView = bgView
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor(named: "AppTextColor")!
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72

        let cellAppearance = UITableViewCell.appearance()
        cellAppearance.textLabel?.font = UIFont(name: "Poppins-SemiBold", size: 16)
        cellAppearance.detailTextLabel?.font = UIFont(name: "Poppins-Regular", size: 14)
        cellAppearance.textLabel?.textColor = UIColor(named: "AppTextColor")!
        cellAppearance.detailTextLabel?.textColor = UIColor(named: "AppTextColor")!
    }

    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

        // Apply custom styling to the cell
        cell.backgroundColor = UIColor(named: "BackgroundAppColor")!
        cell.textLabel?.textColor = UIColor(named: "AppTextColor")!
        cell.detailTextLabel?.textColor = UIColor(named: "AppTextColor")!
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOpacity = 0.1
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.shadowRadius = 4

        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let friend = tmp[indexPath.row]

        selectedFriendUID = friend.uid
        performSegue(withIdentifier: "unwindToSearchFromUserFriends", sender: self)
    }
}

