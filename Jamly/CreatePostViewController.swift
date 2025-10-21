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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    @IBAction func postButtonPressed(_ sender: Any) {
        tabBarController?.tabBar.isHidden = false
        // go back to home once user creates the post
        tabBarController?.selectedIndex = 0
    }
    
}
