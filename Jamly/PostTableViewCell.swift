//
//  PostTableViewCell.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/6/25.
//

import UIKit

class PostTableViewCell: UITableViewCell {

    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var commentsButton: UIButton!
    @IBOutlet weak var likesButton: UIButton!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var postImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
