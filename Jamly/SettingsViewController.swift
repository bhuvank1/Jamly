//
//  SettingsViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/14/25.
//

import UIKit
import FirebaseAuth

public let settingsOptions = ["Account", "Enable Push Notifications", "Night Mode", "About", "Log out", "Delete Account"]

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var settingsTableView: UITableView!
    
    let textCellIdentifier = "SettingsTextCell"
    let textCellIdentifier2 = "SettingsTextCell2"
    let textCellIdentifier3 = "SettingsTextCell3"
    let textCellIdentifier4 = "SettingsTextCell4"
    let textCellIdentifier5 = "SettingsTextCell5"
    let textCellIdentifier6 = "SettingsTextCell6"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTableView.dataSource = self
        settingsTableView.delegate = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Determine which cell identifier to use based on the row
                let cell: UITableViewCell
                
                switch indexPath.row {
                case 0:
                    cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsTextCell", for: indexPath)
                case 1:
                    cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsTextCell2", for: indexPath)
                case 2:
                    cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsTextCell3", for: indexPath)
                case 3:
                    cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsTextCell4", for: indexPath)
                case 4:
                    cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsTextCell5", for: indexPath)
                default:
                    cell = settingsTableView.dequeueReusableCell(withIdentifier: "SettingsTextCell", for: indexPath)
                }

                // Set the content dynamically based on the row
                var content = cell.defaultContentConfiguration()
                content.text = settingsOptions[indexPath.row]
                cell.contentConfiguration = content

                return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (settingsOptions[indexPath.row] == "Log out") {
            do {
                try Auth.auth().signOut()
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") // IF ERROR, REMEMBER TO SET LOGIN VIEW CONTROLLER IN STORYBOARD'S ID TO LoginVC
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let sceneDelegate = windowScene.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    window.rootViewController = loginVC
                    window.makeKeyAndVisible()
                }
            } catch {
                print("Sign out error")
            }
        }
        settingsTableView.deselectRow(at: indexPath, animated: false)
    }

}
