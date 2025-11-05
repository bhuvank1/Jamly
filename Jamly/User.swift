//
//  User.swift
//  Jamly
//
//  Created by Rohan Pant on 11/5/25.
//

import FirebaseFirestore
import FirebaseAuth

class User {
    var uid: String
    var email: String
    var name: String
    var username: String
    var profilePictureURL: String?
    var posts: [Post]  // Array of Post objects
    var friends: [String]  // List of friend userIDs (not full User objects, only IDs)
   
    // Initializer for User class
    init(uid: String, email: String, name: String, username: String, profilePictureURL: String? = nil, posts: [Post] = [], friends: [String] = []) {
        self.uid = uid
        self.email = email
        self.name = name
        self.username = username
        self.profilePictureURL = profilePictureURL
        self.posts = posts
        self.friends = friends
    }
   
    // Function to convert the User object to a Firestore document format
    func toFirestoreData() -> [String: Any] {
        return [
            "uid": uid,
            "email": email,
            "name": name,
            "username": username,
            "profilePictureURL": profilePictureURL ?? "",
            "posts": posts.map { $0.toDictionary() },  // Convert posts to a dictionary format
            "friends": friends,
            "createdAt": Timestamp()
        ]
    }
   
    // Function to initialize User object from Firestore data
    static func fromFirestore(data: [String: Any]) -> User? {
        guard let uid = data["uid"] as? String,
              let email = data["email"] as? String,
              let name = data["name"] as? String,
              let username = data["username"] as? String,
              let profilePictureURL = data["profilePictureURL"] as? String?,
              let postsData = data["posts"] as? [[String: Any]],
              let friends = data["friends"] as? [String] else { return nil }
       
        let posts = [Post]()
       
        return User(uid: uid, email: email, name: name, username: username, profilePictureURL: profilePictureURL, posts: posts, friends: friends)
    }
   
}
