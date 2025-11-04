//
//  CommentsViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/4/25.
//

import UIKit

public let comments = [
    "Braves", "Marlins", "Phillies", "Mets", "Nationals",
    "Pirates", "Brewers", "Reds", "Cubs", "Cardinals",
    "Diamondbacks", "Dodgers", "Giants", "Padres", "Rockies",
    "Rays", "Orioles", "Yankees", "Blue Jays", "Red Sox",
    "Twins", "Guardians", "White Sox", "Tigers", "Royals",
    "Rangers", "Astros", "Angels", "Mariners", "Athletics"
    ]


class CommentsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let textCellIdentifier = "TextCell"
    @IBOutlet weak var commentsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        commentsTableView.dataSource = self
        commentsTableView.delegate = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: textCellIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = comments[indexPath.row]
        
        cell.contentConfiguration = content
        return cell
    }

}
