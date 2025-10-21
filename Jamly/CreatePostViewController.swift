//
//  CreatePostViewController.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 10/16/25.
//

import UIKit

class CreatePostViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func postButtonPressed(_ sender: Any) {
        dismiss(animated: true)
        // go back to home once user creates the post
        tabBarController?.selectedIndex = 0
    }
    
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        dismiss(animated: true)
    }
}
