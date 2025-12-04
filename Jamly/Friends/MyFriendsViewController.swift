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

    @IBOutlet weak var addFriendsButton: UIBarButtonItem!
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
        self.title = "My Friends"
        applyJamThemeStyling()

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

    // MARK: - Styling
    private func applyJamThemeStyling() {
        view.backgroundColor = UIColor(hex: "#FFEFE5")

        tableView.backgroundColor = UIColor(hex: "#FFEFE5")
        let bgView = UIView()
        bgView.backgroundColor = UIColor(hex: "#FFEFE5")
        tableView.backgroundView = bgView
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor(hex: "#3D1F28") 
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72

        let cellAppearance = UITableViewCell.appearance()
        cellAppearance.textLabel?.font = UIFont(name: "Poppins-SemiBold", size: 16)
        cellAppearance.detailTextLabel?.font = UIFont(name: "Poppins-Regular", size: 14)
        cellAppearance.textLabel?.textColor = UIColor(hex: "#3D1F28")
        cellAppearance.detailTextLabel?.textColor = UIColor(hex: "#3D1F28")
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

        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        cell.textLabel?.textColor = UIColor(hex: "#3D1F28")
        cell.detailTextLabel?.textColor = UIColor(hex: "#3D1F28")
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
        performSegue(withIdentifier: "showFriendInSearchFromMyFriends", sender: self)
    }
    @IBAction func addFriendsButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: "showAddFriendsSegue", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showFriendInSearchFromMyFriends",
           let dest = segue.destination as? SearchViewController,
           let uid = selectedFriendUID {
            dest.initialFriendUID = uid
        }
        
        if segue.identifier == "showAddFriendsSegue",
           let nav = segue.destination as? UINavigationController,
           let _ = nav.topViewController as? SearchViewController {
        }
    }
}

