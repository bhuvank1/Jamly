//
//  AccountSettingsVC.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/14/25.
//

import UIKit

public let AccountSettingsOptions = ["Name", "Email account", "Mobile number"]

class AccountSettingsVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var accSettingsTableView: UITableView!
    
    @IBOutlet weak var nameField: UITextField!
    
    @IBOutlet weak var emailField: UITextField!
    
    @IBOutlet weak var mobileNumberField: UITextField!
    let textCellIdentifier = "AccountTextCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        accSettingsTableView.delegate = self
        accSettingsTableView.dataSource = self
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AccountSettingsOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = accSettingsTableView.dequeueReusableCell(withIdentifier: textCellIdentifier, for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = AccountSettingsOptions[indexPath.row]
        cell.contentConfiguration = content
        
        return cell
    }
    


}
