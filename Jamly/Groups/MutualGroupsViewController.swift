//
//  MutualGroupsViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/13/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class MutualGroupsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var groupsTableView: UITableView!
    var post: Post?
    var mutualGroups: [Group] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupsTableView.dataSource = self
        groupsTableView.delegate = self
        
        groupsTableView.backgroundColor = .clear
        view.backgroundColor = UIColor(named: "BackgroundAppColor")!
        navigationItem.title = "Mututal Groups"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        fetchMutualGroups()
    }
    
    func fetchMutualGroups() {
        guard let post else {
            print("ARE YOU RETURNING")
            return}
        guard let currentUserID = Auth.auth().currentUser?.uid else {return}
        let db = Firestore.firestore()
        self.mutualGroups.removeAll()
        
        // fetch mututal groups
        db.collection("groups").whereField("members", arrayContains: currentUserID).getDocuments() { querySnapshot, err in
            if let err = err {
                print("Error in fetching documents: \(err.localizedDescription)")
                return
            }
            
            for document in querySnapshot!.documents {
                if let group = Group(doc: document) {
                    if (group.members.contains(post.userID)) {
                        self.mutualGroups.append(group)
                    }
                }
            }
            print(self.mutualGroups)
            self.groupsTableView.reloadData()
        }
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print(mutualGroups.count)
        return mutualGroups.count
    }
    
    // used Bhuvan's code from GroupsViewController
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = mutualGroups[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "groupCell")
        
        cell.textLabel?.text = group.name

        if !group.creatorDisplayName.isEmpty && group.creatorDisplayName != "Unknown" {
            cell.detailTextLabel?.text = "\(group.creatorDisplayName) • \(group.description)"
        } else {
            cell.detailTextLabel?.text = group.description
        }

        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        
        cell.backgroundColor = .clear
        
        // font
        if let font = UIFont(name: "Poppins-Regular", size: 15) {
            cell.detailTextLabel?.font = font
        }
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 18) {
            cell.textLabel?.font = font
        }
        
        cell.textLabel?.textColor = UIColor(named: "AppTextColor")!
        cell.detailTextLabel?.textColor = UIColor(named: "AppTextColor")!
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedGroup = mutualGroups[indexPath.row]
        performSegue(withIdentifier: "showGroupFromMutualSegue", sender: selectedGroup)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showGroupFromMutualSegue",
           let dest = segue.destination as? GroupDisplayViewController,
           let selectedGroup = sender as? Group {
            dest.group = selectedGroup
            dest.showTitleLabel = true
        }
    }
    
    

}
