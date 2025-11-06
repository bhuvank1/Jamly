//
//  User.swift
//  Jamly
//
//  Created by Rohan Pant on 11/5/25.
//

import FirebaseFirestore

class User {
    var displayName: String
    var email: String
    var mobileNumber: String
    var name: String
    var friends: [String]  // Array of friend userIDs (strings)

    // Initializer for User class
    init(displayName: String, email: String, mobileNumber: String, name: String, friends: [String] = []) {
        self.displayName = displayName
        self.email = email
        self.mobileNumber = mobileNumber
        self.name = name
        self.friends = friends
    }

    // Convert User object to Firestore-compatible dictionary
    func toFirestoreData() -> [String: Any] {
        return [
            "displayName": displayName,
            "email": email,
            "mobileNumber": mobileNumber,
            "name": name,
            "friends": friends  // Add friends array
        ]
    }

    // Static method to initialize a User object from Firestore data (a dictionary)
    static func fromFirestore(data: [String: Any]) -> User? {
        guard let displayName = data["displayName"] as? String,
              let email = data["email"] as? String,
              let mobileNumber = data["mobileNumber"] as? String,
              let name = data["name"] as? String,
              let friends = data["friends"] as? [String] else {
            return nil  // Return nil if any required field is missing or incorrect
        }
       
        return User(displayName: displayName, email: email, mobileNumber: mobileNumber, name: name, friends: friends)
    }
}



