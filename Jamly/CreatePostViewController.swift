//
//  CreatePostViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreatePostViewController: UIViewController {

    @IBOutlet weak var captionField: UITextField!
    @IBOutlet weak var ratingField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    let db = Firestore.firestore()
    
    @IBAction func postButtonPressed(_ sender: Any) {
        guard let user = Auth.auth().currentUser else { return }
        
        // generating postID
        let postRef = db.collection("posts").document()
        let postID = postRef.documentID
        
        let post = Post(userID: user.uid, postID: postID, rating: Int(ratingField.text!) ?? 1, likes: 0, caption: captionField.text!, comments: [], musicName: "Attack")
        
        postRef.setData(post.toDictionary()) { error in
            if let error = error {
                print("Error adding post \(error)")
            } else {
                self.dismiss(animated: true)
                // go back to home once user creates the post
                self.tabBarController?.selectedIndex = 0
            }
        }
    }
    
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}
