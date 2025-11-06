//
//  ViewController.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 10/13/25.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var feedTableView: UITableView!

    // Sample posts
    let samplePosts: [Post] = [
        Post(
            userID: "user001",
            postID: "post001",
            rating: 5,
            likes: ["user002", "user003", "user004"],
            caption: "Can’t stop replaying this one. Feels like summer again ☀️",
            comments: [
                Comment(userID: "user123", commentText: "Love this track!"),
                Comment(userID: "user456", commentText: "Such a vibe 🔥")
            ],
            musicName: "Sunset Lover - Petit Biscuit"
        ),
        Post(
            userID: "user002",
            postID: "post002",
            rating: 4,
            likes: ["user001", "user005"],
            caption: "Late night study playlist vibes 🎧",
            comments: [
                Comment(userID: "user003", commentText: "Adding this to my queue!")
            ],
            musicName: "Night Trouble - Petit Biscuit"
        ),
        Post(
            userID: "user003",
            postID: "post003",
            rating: 3,
            likes: ["user004"],
            caption: "Trying out something new — thoughts?",
            comments: [],
            musicName: "Electric Feel - MGMT"
        )
    ]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        feedTableView.dataSource = self
        feedTableView.delegate = self
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        samplePosts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = feedTableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as? PostTableViewCell else {
            fatalError("Could not deque post cell")
        }
        
        let post = samplePosts[indexPath.row]
        cell.postImageView.image = UIImage(named: "Jamly_LogoPDF")
        cell.usernameLabel.text = "monaaaaa.mitruhhhhh"
        return cell
    }
    
}

