//
//  SettingsViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/14/25.
//

import UIKit
import FirebaseAuth

let settingsOptions: [SettingOption] =
[SettingOption(title: "Account", type: .navigation),
 SettingOption(title: "Enable Push Notifications", type: .toggle),
 SettingOption(title: "Dark Mode", type: .toggle),
 SettingOption(title: "About", type: .navigation),
 SettingOption(title: "Log out", type: .action),
 SettingOption(title: "Delete Account",type: .action)]

let defaults = UserDefaults.standard

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var settingsTableView: UITableView!
    
    let textCellIdentifier = "SettingsTextCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTableView.dataSource = self
        settingsTableView.delegate = self
    }
    
    @IBAction func darkModeToggled(_ sender: UISwitch) {
        if (sender.isOn) {
            overrideUserInterfaceStyle = .dark
            defaults.set(true, forKey: "jamlyDarkMode")
        } else {
            overrideUserInterfaceStyle = .light
            defaults.set(false, forKey: "jamlyDarkMode")
        }
        
        // apply appearance to other screen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = sender.isOn ? .dark : .light
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTextCell", for: indexPath) as! SettingsTableViewCell
        let option = settingsOptions[indexPath.row]
        
        cell.cellLabel.text = option.title
        cell.darkModeSwitch.isHidden = true
        cell.notificationSwitch.isHidden = true
        cell.accessoryType = .none
        
        switch option.type {
        case .navigation:
            cell.accessoryType = .disclosureIndicator
            
        case .toggle:
            if (option.title == "Dark Mode") {
                cell.darkModeSwitch.isHidden = false
                cell.darkModeSwitch.isOn = defaults.bool(forKey: "jamlyDarkMode")
                cell.darkModeSwitch.addTarget(self, action: #selector(darkModeToggled(_:)), for: .valueChanged)
            }
            if (option.title == "Enable Push Notifications" ) {
                cell.notificationSwitch.isHidden = false
            }
            
        case .action:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let option = settingsOptions[indexPath.row]
        return option.type == .navigation || option.type == .action ? indexPath : nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = settingsOptions[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch option.title {
        case "Account":
            performSegue(withIdentifier: "AccountSegue", sender: self)
        case "Log out":
            handleLogout()
        default:
            break
        }

        settingsTableView.deselectRow(at: indexPath, animated: false)
    }
    
    func handleLogout() {
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

}
