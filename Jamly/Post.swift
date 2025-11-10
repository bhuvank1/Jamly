//
//  Post.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit

class Post {
    var rating: Int
    var likes: [String]
    var caption: String
    var comments: [Comment]
    var musicName: String
    var userID: String
    var postID: String
    var displayName: String
    
    required init(userID: String, postID: String, rating: Int, likes: [String], caption: String, comments: [Comment], musicName: String, displayName: String) {
        self.userID = userID
        self.postID = postID
        self.rating = rating
        self.likes = likes
        self.caption = caption
        self.comments = comments
        self.musicName = musicName
        self.displayName = displayName
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "userID": userID,
            "postID": postID,
            "rating": rating,
            "likes": likes,
            "caption": caption,
            "comments": comments,
            "musicName": musicName,
            "displayName": displayName
            ]
    }
}
