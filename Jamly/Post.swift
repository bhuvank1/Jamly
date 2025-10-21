//
//  Post.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit

class Post {
    var rating: Int
    var likes: Int
    var caption: String
    var comments: [String]
    var musicName: String
    var albumPic: UIImage
    
    required init(rating: Int, likes: Int, caption: String, comments: [String], musicName: String, albumPic: UIImage) {
        self.rating = rating
        self.likes = likes
        self.caption = caption
        self.comments = comments
        self.musicName = musicName
        self.albumPic = albumPic
    }
}
