//
//  ViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/13/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        checkSpotifyConnection()
    }

    func displayPopup() {
        let controller = UIAlertController(
            title: "Spotify",
            message: "Connect to your Spotify account to continue",
            preferredStyle: .alert)
        
        let connectAction = UIAlertAction(title: "Connect to Spotify", style: .default, handler: alertHander(alert:))
        controller.addAction(connectAction)
        controller.preferredAction = connectAction
        
        present(controller, animated: true)
    }
    
    func alertHander(alert:UIAlertAction) {
        SpotifyAuthManager.shared.signIn {
            success in DispatchQueue.main.async {
                if success {
                    let alert = UIAlertController(title: "Connected!", message: "You can now use Spotify features.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    print("WE CONNECTED YAY")
                } else {
                    let alert = UIAlertController(title: "Login Failed", message: "Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                    self.displayPopup()
                }
            }
        }
    }
    
    //Helper function to check if there is already a valid connection
    private func checkSpotifyConnection() {
        SpotifyAuthManager.shared.getValidAccessToken { token in
            DispatchQueue.main.async {
                let connected = token != nil
                if (connected == false) {
                    self.displayPopup()
                }
            }
        }
    }
}

