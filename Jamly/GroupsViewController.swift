//
//  GroupsViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/7/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class GroupsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var GroupsTableView: UITableView!
    
    private var groupsCollection: [Group] = []
    
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Groups"

        GroupsTableView.dataSource = self
        GroupsTableView.delegate = self
      
        retrieveUserGroups()

    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print(groupsCollection.count)
        return groupsCollection.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = GroupsTableView.dequeueReusableCell(withIdentifier: "GroupsTextCell", for: indexPath) as? GroupTableViewCell else {
            fatalError("Could not deque cell")
        }
        
        let group = groupsCollection[indexPath.row]
        cell.groupNameLabel.text = group.name

        cell.groupDescrpText.text = group.description

        print(group.description)
        
        // ADD ARTIST NAME AND TRACK TITLE OF SIMILAR SONG
        
        return cell
    }
    
    func retrieveUserGroups() {
        guard let user = Auth.auth().currentUser else { return }
        print("Current UID:", user.uid)
        
        // find groups where current user is a member
        db.collection("groups")
            .whereField("members", arrayContains: user.uid)
            .getDocuments { querySnapshot, error in
                
                if let error = error {
                    print("Error fetching groups: \(error.localizedDescription)")
                    return
                }
                
                self.groupsCollection.removeAll()
                
                guard let documents = querySnapshot?.documents else { return }
                
                for document in documents {
                    let data = document.data()
                    let name = data["name"] as? String ?? "Group Name"
                    let description = data["description"] as? String ?? "Group description here"
                    let creatorID = data["creatorID"] as? String ?? "Unknown ID"
                    let creatorDisplayName = data["creatorDisplayName"] as? String ?? "Unknown Display Name"
                    let members = data["members"] as? [String] ?? []
                    let postsID = data["postsID"] as? [String] ?? []
                    
                    let newGroup = Group(
                        name: name,
                        description: description,
                        creatorID: creatorID,
                        creatorDisplayName: creatorDisplayName,
                        members: members,
                        postsID: postsID
                    )
                    
                    self.groupsCollection.append(newGroup)
                }
                
                self.GroupsTableView.reloadData()

            }
    }


}
