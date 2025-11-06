//
//  SettingsTableViewCell.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/4/25.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    @IBOutlet weak var notificationSwitch: UISwitch!

    @IBOutlet weak var cellLabel: UILabel!
    @IBOutlet weak var darkModeSwitch: UISwitch!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
