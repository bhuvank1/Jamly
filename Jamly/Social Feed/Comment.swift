//
//  Comment.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/5/25.
//

import Foundation

class Comment {
    
    var userID: String
    var commentText: String
    
    required init(userID: String, commentText: String) {
        self.userID = userID
        self.commentText = commentText
    }
    
}
