//
//  SettingsViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/14/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

let settingsOptions: [SettingOption] =
[SettingOption(title: "Account", type: .navigation),
 SettingOption(title: "Enable Reminder", type: .toggle),
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
        self.title = "Settings"
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
    
    @IBAction func notificationSwitchToggled(_ sender: UISwitch) {
        if (sender.isOn) {
            UNUserNotificationCenter.current().requestAuthorization(options: .alert) { granted, error in
                if granted { // got permission
                    print("All set!")
                    DispatchQueue.main.async {
                        self.getScheduledInterval(sender: sender)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                    DispatchQueue.main.async {
                        sender.isOn = false
                        defaults.set(false, forKey: "jamlyNotifications")
                    }
                }
            }
        } else {
            // turn off pending notfications
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    func getScheduledInterval(sender: UISwitch) {
        let controller = UIAlertController (title: "Input Interval", message: "Enter the number of HOURS you would like to be reminded to open Jamly after inactivity.", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        // if user cancels, revert switch
            sender.isOn = false
            defaults.set(false, forKey: "jamlyNotifications")
        }
        
        controller.addTextField() {
            (textField) in
            textField.placeholder = "Enter a number"
            textField.keyboardType = .decimalPad
        }
        
        let okAction = UIAlertAction(title: "Ok", style: .default) {
            (action) in
            guard let timeInterval = controller.textFields![0].text, !timeInterval.isEmpty else {
                self.makePopup(popupTitle: "Error", popupMessage: "Input cannot be empty")
                DispatchQueue.main.async {
                    sender.isOn = false
                    defaults.set(false, forKey: "jamlyNotifications")
                }
                return
            }
            
            guard let timeIntervalValue = Double(timeInterval) else {
                self.makePopup(popupTitle: "Error", popupMessage: "Make sure to input a value")
                sender.isOn = false
                defaults.set(false, forKey: "jamlyNotifications")
                return
            }
            
            guard timeIntervalValue > 0 else {
                self.makePopup(popupTitle: "Error", popupMessage: "Interval must be more than 0 hours.")
                sender.isOn = false
                defaults.set(false, forKey: "jamlyNotifications")
                return
            }
            
            self.scheduleNotification(timeIntervalValue: timeIntervalValue)
            defaults.set(false, forKey: "jamlyNotifications")
        }
        
        controller.addAction(cancelAction)
        controller.addAction(okAction)
        present(controller, animated: true)
    }
    
    private func scheduleNotification(timeIntervalValue:Double) {
        // create content
        let content = UNMutableNotificationContent()
        content.title = "Jamly misses you."
        content.subtitle = "You have not visited us in " + String(timeIntervalValue) + " hours"
        content.sound = UNNotificationSound.default
        
        // create trigger
        // CHANGE TO MULTIPLY BY 3600
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeIntervalValue*3600, repeats: true)
        
        // combine it all into a request
        let request = UNNotificationRequest(identifier: "myNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        
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
            if (option.title == "Enable Reminder" ) {
                cell.notificationSwitch.isHidden = false
                cell.notificationSwitch.isOn = defaults.bool(forKey: "jamlyNotifications")
                cell.notificationSwitch.addTarget(self, action: #selector(notificationSwitchToggled(_:)), for: .valueChanged)
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
        case "About":
            performSegue(withIdentifier: "AboutSegue", sender: self)
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
            // erase spotify tokens
            try Auth.auth().signOut()
            SpotifyAuthManager.shared.clearTokens()
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
                
                // delete any database info about this user
                self.deleteDatabaseInfo()
                
                // delete all posts from this user
                self.deleteUserPots()
                
                // delete comments from user
                self.deleteUserComments()
                
                // delete likes from user
                self.deleteUserLikes()
                
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
    
    func deleteDatabaseInfo() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        
        let db = Firestore.firestore()
        db.collection("userInfo").document(uid).delete { error in
            if let error = error {
                print("Error deleting Firestore data: \(error.localizedDescription)")
            } else {
                print("User data deleted from Firestore.")
            }
        }
    }
    
    func deleteUserPots() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("posts").whereField("userID", isEqualTo: user.uid).getDocuments() { (querySnapshot, error) in
            if let error = error {
                print("Error fetching user posts: \(error.localizedDescription)")
                return
            }
            
            guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                print("No posts found for user.")
                return
            }
            
            // Delete each post
            for document in documents {
                document.reference.delete { error in
                    if let error = error {
                        print("Error deleting post \(document.documentID): \(error.localizedDescription)")
                    } else {
                        print("Successfully deleted post \(document.documentID)")
                    }
                }
            }
        }
        
    }
    
    func makePopup(popupTitle:String, popupMessage:String) {
            
            let controller = UIAlertController(
                title: popupTitle,
                message: popupMessage,
                preferredStyle: .alert)
            
            controller.addAction(UIAlertAction(title: "OK", style: .default))
            present(controller,animated:true)
        }
    
    func deleteUserComments() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("posts").getDocuments() { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            for doc in docs {
                var comments = doc["comments"] as? [[String:Any]] ?? []
                comments.removeAll { $0["userID"] as? String == user.uid }
                db.collection("posts").document(doc.documentID).updateData(["comments": comments])
            }
        }
    }
    
    func deleteUserLikes() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("posts").getDocuments() { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            for doc in docs {
                var likes = doc["likes"] as? [String] ?? []
                likes.removeAll { $0 == user.uid }
                db.collection("posts").document(doc.documentID).updateData(["likes": likes])
            }
        }
    }

}
