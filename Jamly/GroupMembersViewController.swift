//
//  GroupMembersViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class GroupMembersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var group: Group!
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var membersTable: UITableView!
    
    private let db = Firestore.firestore()

    // Data sources
    private var currentMembers: [AppUser] = []
    private var addCandidates: [AppUser] = []
    // Toggle based on segmented control
    private var isAddMode = false

    // Computed datasource based on the toggle
    private var dataSource: [AppUser] {
        return isAddMode ? addCandidates : currentMembers
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = group?.name
        
        membersTable.dataSource = self
        membersTable.delegate = self
        membersTable.allowsSelection = false // default in View Members
        
        // THEME
        let appBg = UIColor(hex: "#FFEFE5")
        let accent = UIColor(hex: "#FFC1CC")

        view.backgroundColor = appBg
        membersTable.backgroundColor = appBg
        membersTable.separatorColor = accent.withAlphaComponent(0.6)
        segmentedControl.backgroundColor = appBg
        segmentedControl.selectedSegmentTintColor = accent
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchMembersAndCandidates()
    }
    
    @IBAction func onSegmentChanged(_ sender: Any) {
        isAddMode = (segmentedControl.selectedSegmentIndex == 1)
        membersTable.allowsSelection = isAddMode
        membersTable.reloadData()

        // Debug print statements
        print("\n--- SEGMENT CHANGED ---")
        print("isAddMode:", isAddMode ? "Add Mode (showing addCandidates)" : "Members Mode (showing currentMembers)")
        print("Current Members (\(currentMembers.count)):")
        for member in currentMembers {
            print("• \(member.displayName) - \(member.email)")
        }

        print("Add Candidates (\(addCandidates.count)):")
        for candidate in addCandidates {
            print("• \(candidate.displayName) - \(candidate.email)")
        }

        let activeSource = isAddMode ? addCandidates : currentMembers
        print("Active dataSource (\(activeSource.count) users):")
        for user in activeSource {
            print("→ \(user.displayName) [\(user.email)]")
        }
        print("-----------------------\n")
    }

    // Load members and friends
    private func fetchMembersAndCandidates() {
        // Refresh group to get latest
        db.collection("groups").document(group.id).getDocument(source: .default) { [weak self] snap, _ in
            guard let self = self, let snap = snap, let refreshed = Group(doc: snap) else { return }
            self.group = refreshed

            // 1) Load current member profiles
            self.loadUsersByUIDs(refreshed.members) { users in
                self.currentMembers = users
                self.segmentedControl.setTitle("Members (\(users.count))", forSegmentAt: 0)

                // 2) Now load current users friends minus existing members
                self.fetchCurrentUserFriendUIDs { friendUIDs in
                    let existing = Set(refreshed.members)
                    let friendNonMembers = friendUIDs.filter { !existing.contains($0) }
                    if friendNonMembers.isEmpty {
                        self.addCandidates = []
                        self.segmentedControl.setTitle("Add (0)", forSegmentAt: 1)
                        self.membersTable.reloadData()
                        return
                    }

                    self.loadUsersByUIDs(friendNonMembers) { users in
                        // Sorting
                        self.addCandidates = users.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                        self.segmentedControl.setTitle("Add (\(self.addCandidates.count))", forSegmentAt: 1)
                        self.membersTable.reloadData()
                    }
                }
            }
        }
    }

    private func fetchCurrentUserFriendUIDs(completion: @escaping ([String]) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { completion([]); return }
        db.collection("userInfo").document(uid).getDocument { snap, _ in
            guard let data = snap?.data() else { completion([]); return }
            let friends = data["friends"] as? [String] ?? []
            completion(friends)
        }
    }

    // Helper to load user documents in chunks of up to 10 ids for a list of uids
    private func loadUsersByUIDs(_ uids: [String], completion: @escaping ([AppUser]) -> Void) {
        guard !uids.isEmpty else { completion([]); return }

        let chunks = stride(from: 0, to: uids.count, by: 10).map {
            Array(uids[$0..<min($0 + 10, uids.count)])
        }

        let g = DispatchGroup()
        var fetched: [AppUser] = []

        for chunk in chunks {
            g.enter()
            db.collection("userInfo")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments { snap, _ in
                    if let docs = snap?.documents {
                        fetched.append(contentsOf: docs.compactMap(AppUser.init(doc:)))
                    }
                    g.leave()
                }
        }

        g.notify(queue: .main) {
            // Preserve original order (when needed), but here we’re fine returning in arbitrary order
            completion(fetched)
        }
    }

    // MARK: - UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let user = dataSource[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "MemberCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "MemberCell")

        cell.textLabel?.text = user.displayName.isEmpty ? "(no name)" : user.displayName
        cell.detailTextLabel?.text = user.email
        cell.detailTextLabel?.textColor = .secondaryLabel

        // Selection only in Add mode
        cell.selectionStyle = isAddMode ? .default : .none
        cell.accessoryType = isAddMode ? .disclosureIndicator : .none
        
        //Theme
        cell.backgroundColor = UIColor(hex: "#FFEFE5")
        let selected = UIView()
        selected.backgroundColor = UIColor(hex: "#FFC1CC").withAlphaComponent(0.25)
        cell.selectedBackgroundView = selected
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard isAddMode else { return } // Only allowed to select rows in Add Mode
        tableView.deselectRow(at: indexPath, animated: true)

        let candidate = addCandidates[indexPath.row]

        db.collection("groups").document(group.id)
            .updateData([
                "members": FieldValue.arrayUnion([candidate.uid]),
                "lastActivityAt": Timestamp(date: Date())
            ]) { [weak self] err in
                guard let self = self else { return }
                if let err = err {
                    print("Add failed: \(err.localizedDescription)")
                    return
                }
                // Refresh lists & update counts
                self.fetchMembersAndCandidates()
            }
    }
}
