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
        case "Delete Account":
            handleDeleteAccount()
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
    
    func handleDeleteAccount() {
        guard let user = Auth.auth().currentUser else {return}
        
        // firebase requires reauthentication of user before deleting account so prompt user to re-enter password
        let controller = UIAlertController (title: "Confirm Password", message: "Re-enter password to delete account.", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        controller.addTextField() {
            (textField) in
            textField.isSecureTextEntry = true
            textField.placeholder = "Enter password"
        }
        
        let okAction = UIAlertAction(title: "Delete", style: .destructive) {
            (action) in
            guard let password = controller.textFields![0].text,
                  let email = user.email else {return}
            
            // now reauthentication
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            user.reauthenticate(with: credential) { authResult, error in
                if let error = error {
                    print("Reauthentication failed: \(error.localizedDescription)")
                    self.makePopup(popupTitle: "Error", popupMessage: "Incorrect password")
                    return
                }
                
                user.delete() { error in
                    if let error = error {
                        print("Error deleting user: \(error.localizedDescription)")
                    } else {
                        print("Account successfully deleted.")
                        
                        // Clear any user-related data if needed
                                do {
                                    try Auth.auth().signOut()
                                } catch let signOutError as NSError {
                                    print("Error signing out: \(signOutError.localizedDescription)")
                                }
                        
                        // reroute back to login screen
                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC")
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let sceneDelegate = windowScene.delegate as? SceneDelegate,
                           let window = sceneDelegate.window {
                            window.rootViewController = loginVC
                            window.makeKeyAndVisible()
                        }
                    }
                }
            }
        }
        
        controller.addAction(cancelAction)
        controller.addAction(okAction)
        present(controller, animated: true)
    }
    
    func makePopup(popupTitle:String, popupMessage:String) {
            
            let controller = UIAlertController(
                title: popupTitle,
                message: popupMessage,
                preferredStyle: .alert)
            
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            present(controller,animated:true)
        }

}
