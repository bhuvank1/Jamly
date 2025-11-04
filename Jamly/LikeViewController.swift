//
//  LikeViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/4/25.
//

import UIKit

public let likes = [
    "Braves", "Marlins", "Phillies", "Mets", "Nationals",
    "Pirates", "Brewers", "Reds", "Cubs", "Cardinals",
    "Diamondbacks", "Dodgers", "Giants", "Padres", "Rockies",
    "Rays", "Orioles", "Yankees", "Blue Jays", "Red Sox",
    "Twins", "Guardians", "White Sox", "Tigers", "Royals",
    "Rangers", "Astros", "Angels", "Mariners", "Athletics"
    ]

class LikeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var likesTableView: UITableView!
    let textCellIdentifier = "TextCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        likesTableView.dataSource = self
        likesTableView.delegate = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return likes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: textCellIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = likes[indexPath.row]
        
        cell.contentConfiguration = content
        return cell
    }
    
}
