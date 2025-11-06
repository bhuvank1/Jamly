//
//  UserFriendsViewController.swift
//  Jamly
//
//  Created by Pant, Rohan on 11/6/25.
//

import UIKit

class UserFriendsViewController: UIViewController, UITableViewDataSource {
   
    @IBOutlet weak var tableView: UITableView!
    var friends: [User] = []  // Array to hold the list of friend User objects
   
    override func viewDidLoad() {
        super.viewDidLoad()
       
        // Set the data source for the table view
        tableView.dataSource = self
    }
   
    // UITableViewDataSource method: number of rows in the table view
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count  // The number of friends
    }
   
    // UITableViewDataSource method: configure each cell in the table view
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath)
       
        let friend = friends[indexPath.row]
       
        // Set the cell's text label to the friend's displayName
        cell.textLabel?.text = friend.displayName
       
        return cell
    }
   
    // Method to update the list of friends
    func updateFriendsList(friends: [User]) {
        self.friends = friends
        self.tableView.reloadData()  // Reload the table view to display friends
    }
}
