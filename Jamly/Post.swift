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
    var userID: String
    var postID: String
    var trackObject: [String: Any]
    
    required init(userID: String, postID: String, rating: Int, likes: [String], caption: String, comments: [Comment], trackObject: [String: Any]) {
        self.userID = userID
        self.postID = postID
        self.rating = rating
        self.likes = likes
        self.caption = caption
        self.comments = comments
        self.trackObject = trackObject
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "userID": userID,
            "postID": postID,
            "rating": rating,
            "likes": likes,
            "caption": caption,
            "comments": comments,
            "trackObject": trackObject
            ]
    }
}
