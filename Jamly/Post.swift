//
//  Post.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit

import FirebaseFirestore

class Post {
    var rating: Int
    var likes: [String]
    var caption: String
    var comments: [Comment]
    var musicName: String
    var userID: String
    var postID: String
    
    required init(userID: String, postID: String, rating: Int, likes: [String], caption: String, comments: [Comment], musicName: String) {
        self.userID = userID
        self.postID = postID
        self.rating = rating
        self.likes = likes
        self.caption = caption
        self.comments = comments
        self.musicName = musicName
    }
   
    // Convert Post object to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        return [
            "userID": userID,
            "postID": postID,
            "rating": rating,
            "likes": likes,
            "caption": caption,
            "comments": comments,
            "musicName": musicName
        ]
    }
   
    // Static function to convert Firestore data (a dictionary) to a Post object
    static func fromFirestore(data: [String: Any]) -> Post? {
        // Safely unwrap the data from Firestore and return a Post object
        guard let userID = data["userID"] as? String,
              let postID = data["postID"] as? String,
              let rating = data["rating"] as? Int,
              let likes = data["likes"] as? Int,
              let caption = data["caption"] as? String,
              let comments = data["comments"] as? [String],
              let musicName = data["musicName"] as? String else {
            return nil  // Return nil if any required field is missing or incorrect
        }
       
        return Post(userID: userID, postID: postID, rating: rating, likes: likes, caption: caption, comments: comments, musicName: musicName)
    }
}
