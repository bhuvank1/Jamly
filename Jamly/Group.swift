//
//  Group.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/7/25.
//

import UIKit

class Group {
    var name: String
    var description: String
    var creatorID: String
    var creatorDisplayName: String
    var members: [String]
    var postsID: [String]
    
    required init(name: String, description: String, creatorID: String, creatorDisplayName: String, members: [String], postsID: [String]) {
        self.name = name
        self.creatorID = creatorID
        self.description = description
        self.creatorDisplayName = creatorDisplayName
        self.members = members
        self.postsID = postsID
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "creatorID": creatorID,
            "description": description,
            "creatorDisplayName": creatorDisplayName,
            "members": members,
            "postsID": postsID
        ]
    }
}
