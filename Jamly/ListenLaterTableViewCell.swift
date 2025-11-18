//
//  ListenLaterTableViewCell.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/10/25.
//

import UIKit

class ListenLaterTableViewCell: UITableViewCell {

    @IBOutlet weak var artistNameLabel: UILabel!
    @IBOutlet weak var trackNameLabel: UILabel!
    @IBOutlet weak var trackImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        
        if let font = UIFont(name: "Poppins-SemiBold", size: 17) {
            trackNameLabel.font = font
        }
        
        if let font = UIFont(name: "Poppins-Regular", size: 14) {
            artistNameLabel.font = font
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
