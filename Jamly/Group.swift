//
//  Group.swift
//  Jamly
//
//  Created by Bhuvan Kannaeganti on 11/09/25.
//


import FirebaseFirestore

struct Group {
    let id: String
    let name: String
    let description: String
    let creatorID: String
    let creatorDisplayName: String
    let members: [String]
    let playlist: [Track]

    init?(doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]
        guard
            let name = data["name"] as? String,
            let description = data["description"] as? String,
            let creatorID = data["creatorID"] as? String
        else { return nil }

        self.id = doc.documentID
        self.name = name
        self.description = description
        self.creatorID = creatorID
        self.creatorDisplayName = "Unknown"
        self.members = data["members"] as? [String] ?? []
        
        if let rawPlaylist = data["playlist"] as? [[String: Any]] {
            self.playlist = rawPlaylist.compactMap { Track.fromDictionary($0) }
        } else {
            self.playlist = []
        }
    }
}
