//
//  ViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/13/25.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var spotifyButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Jamly"
        // Do any additional setup after loading the view.
    }
    @IBAction func spotifyButtonPressed(_ sender: Any) {
        SpotifyAuthManager.shared.signIn {
            success in DispatchQueue.main.async {
                if success {
                    
                    let alert = UIAlertController(title: "Connected 🎉", message: "You can now use Spotify features.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.spotifyButton.titleLabel?.text = "Connected"
                    self.present(alert, animated: true)
                } else {
                    let alert = UIAlertController(title: "Login Failed", message: "Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.spotifyButton.titleLabel?.text = "Failed"
                    self.present(alert, animated: true)
                    
                }
            }
        }
    }
    

}

