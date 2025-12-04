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
 SettingOption(title: "Spotify", type: .button),
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
        settingsTableView.backgroundColor = .clear
        view.backgroundColor = UIColor(named: "BackgroundAppColor")!
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
    
    @IBAction func connectButtonPressed(_ sender: UIButton) {
        let buttonTitle = sender.configuration?.title
        if (buttonTitle == "Connect") {
            let controller = UIAlertController(
                title: "Spotify",
                message: "Connect to your Spotify account to continue",
                preferredStyle: .alert)
            
            let connectAction = UIAlertAction(title: "Connect to Spotify", style: .default){ _ in
                self.alertHander(for: sender)
            }

            controller.addAction(connectAction)
            controller.preferredAction = connectAction
            
            present(controller, animated: true)
        } else if (buttonTitle == "Disconnect") {
            let controller = UIAlertController(
                title: "Disconnect from Spotify",
                message: "Are you sure you want to disconnect from your spotify account?",
                preferredStyle: .alert)
            
            let connectAction = UIAlertAction(title: "Disconnect", style: .destructive){ _ in
                self.spotifyLogOut(sender)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            controller.addAction(connectAction)
            controller.addAction(cancelAction)
            controller.preferredAction = cancelAction
            
            present(controller, animated: true)
        }
    }
    
    func alertHander(for button: UIButton) {
        SpotifyAuthManager.shared.signIn { success in
            DispatchQueue.main.async {
                if success {
                    // Update button title
                    var config = button.configuration
                    config?.title = "Disconnect"
                    button.configuration = config

                    let alert = UIAlertController(
                        title: "Connected!",
                        message: "You can now use Spotify features.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)

                } else {
                    let alert = UIAlertController(
                        title: "Login Failed",
                        message: "Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    func spotifyLogOut(_ button: UIButton) {
        SpotifyAuthManager.shared.disconnect()
        DispatchQueue.main.async {
                // update button title
                var config = button.configuration
                config?.title = "Connect"
                button.configuration = config

                // show confirmation alert
                let alert = UIAlertController(
                    title: "Disconnected",
                    message: "You have successfully logged out of Spotify.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
    }
    
    @IBAction func notificationSwitchToggled(_ sender: UISwitch) {
        if sender.isOn {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    
                    DispatchQueue.main.async {
                        if granted {
                            print("Notification permission granted.")
                            defaults.set(true, forKey: "jamlyNotifications")
                            SettingsViewController.scheduleDailyNudge()
                        } else {
                            print("Notification permission denied.")
                            
                            // Reset toggle
                            sender.isOn = false
                            defaults.set(false, forKey: "jamlyNotifications")
                            
                            // Show message telling user how to enable again
                            let alert = UIAlertController(
                                title: "Notifications Disabled",
                                message: "To enable notifications, go to iPhone Settings → Jamly → Notifications.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(alert, animated: true)
                        }
                    }
                }
            } else {
                // user turned notifications OFF
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                defaults.set(false, forKey: "jamlyNotifications")
            }
    }
    
    static func scheduleDailyNudge() {
        let center = UNUserNotificationCenter.current()
        
        // Cancel existing nudge
        center.removePendingNotificationRequests(withIdentifiers: ["dailyNudge"])
        
        let content = UNMutableNotificationContent()
        content.title = "We miss you!"
        content.body = "You haven't visted Jamly today."
        content.sound = .default
        
        // Schedule for 7 PM every day
        var dateComponents = DateComponents()
        dateComponents.hour = 19 // 7 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "dailyNudge", content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule daily nudge: \(error.localizedDescription)")
            }
        }
    }
    
//    func getScheduledInterval(sender: UISwitch) {
//        let controller = UIAlertController (title: "Input Interval", message: "Enter the number of HOURS you would like to be reminded to open Jamly after inactivity.", preferredStyle: .alert)
//        
//        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
//        // if user cancels, revert switch
//            sender.isOn = false
//            defaults.set(false, forKey: "jamlyNotifications")
//        }
//        
//        controller.addTextField() {
//            (textField) in
//            textField.placeholder = "Enter a number"
//            textField.keyboardType = .decimalPad
//        }
//        
//        let okAction = UIAlertAction(title: "Ok", style: .default) {
//            (action) in
//            guard let timeInterval = controller.textFields![0].text, !timeInterval.isEmpty else {
//                self.makePopup(popupTitle: "Error", popupMessage: "Input cannot be empty")
//                DispatchQueue.main.async {
//                    sender.isOn = false
//                    defaults.set(false, forKey: "jamlyNotifications")
//                }
//                return
//            }
//            
//            guard let timeIntervalValue = Double(timeInterval) else {
//                self.makePopup(popupTitle: "Error", popupMessage: "Make sure to input a value")
//                sender.isOn = false
//                defaults.set(false, forKey: "jamlyNotifications")
//                return
//            }
//            
//            guard timeIntervalValue > 0 else {
//                self.makePopup(popupTitle: "Error", popupMessage: "Interval must be more than 0 hours.")
//                sender.isOn = false
//                defaults.set(false, forKey: "jamlyNotifications")
//                return
//            }
//            
//            self.scheduleNotification(timeIntervalValue: timeIntervalValue)
//            defaults.set(false, forKey: "jamlyNotifications")
//        }
//        
//        controller.addAction(cancelAction)
//        controller.addAction(okAction)
//        present(controller, animated: true)
//    }
//    
//    private func scheduleNotification(timeIntervalValue:Double) {
//        // create content
//        let content = UNMutableNotificationContent()
//        content.title = "Jamly misses you."
//        content.subtitle = "You have not visited us in " + String(timeIntervalValue) + " hours"
//        content.sound = UNNotificationSound.default
//        
//        // create trigger
//        // CHANGE TO MULTIPLY BY 3600
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeIntervalValue*3600, repeats: true)
//        
//        // combine it all into a request
//        let request = UNNotificationRequest(identifier: "myNotification", content: content, trigger: trigger)
//        UNUserNotificationCenter.current().add(request)
//        
//        
//    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTextCell", for: indexPath) as! SettingsTableViewCell
        let option = settingsOptions[indexPath.row]
        
        cell.backgroundColor = UIColor(named: "BackgroundAppColor")!
        cell.cellLabel.text = option.title
        if let font = UIFont(name: "Poppins-Regular", size: 16) {
            cell.cellLabel.font = font
        }
        cell.darkModeSwitch.isHidden = true
        cell.notificationSwitch.isHidden = true
        cell.connectbutton.isHidden = true
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
            
        case .button:
            if (option.title == "Spotify") {
                cell.connectbutton.isHidden = false
                var config = UIButton.Configuration.filled()
                config.baseBackgroundColor = UIColor(hex: "#FFC1CC")
                config.baseForegroundColor = UIColor(hex: "#3D1F28")
                config.cornerStyle = .medium
                config.titleAlignment = .center
                
                //Helper function to check if there is already a valid connection
                    SpotifyAuthManager.shared.getValidAccessToken { token in
                        DispatchQueue.main.async {
                            let connected = token != nil
                            if (connected == false) {
                                config.title = "Connect"
                                cell.connectbutton.configuration = config
                            } else {
                                config.title = "Disconnect"
                                cell.connectbutton.configuration = config
                            }
                        }
                    }
                
                cell.connectbutton.addTarget(self, action: #selector(connectButtonPressed(_:)), for: .touchUpInside)
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
