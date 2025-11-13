//
//  GroupsViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/09/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class GroupsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var groupsTableView: UITableView!
    private let refresh = UIRefreshControl()
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var groups: [Group] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Groups"

        groupsTableView.dataSource = self
        groupsTableView.delegate = self

        groupsTableView.refreshControl = refresh
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        reloadGroups()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadGroups()
    }
    
    @objc private func handleRefresh() {
        reloadGroups()
    }
    
    private func reloadGroups() {
        guard let uid = Auth.auth().currentUser?.uid else {
            groups = []
            groupsTableView.reloadData()
            refresh.endRefreshing()
            return
        }

        db.collection("groups")
            .whereField("members", arrayContains: uid)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.refresh.endRefreshing()

                if let error = error {
                    print("Fetch groups error:", error)
                    self.groups = []
                    self.groupsTableView.reloadData()
                    return
                }

                self.groups = snapshot?.documents.compactMap(Group.init(doc:)) ?? []
                self.groupsTableView.reloadData()
            }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let group = groups[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "GroupCell")
        
        cell.textLabel?.text = group.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)

        if !group.creatorDisplayName.isEmpty && group.creatorDisplayName != "Unknown" {
            cell.detailTextLabel?.text = "\(group.creatorDisplayName) • \(group.description)"
        } else {
            cell.detailTextLabel?.text = group.description
        }

        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.numberOfLines = 2
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedGroup = groups[indexPath.row]
        performSegue(withIdentifier: "showGroup", sender: selectedGroup)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showGroup",
           let dest = segue.destination as? GroupDisplayViewController,
           let selectedGroup = sender as? Group {
            dest.group = selectedGroup
            dest.showTitleLabel = false
        }
    }

}
