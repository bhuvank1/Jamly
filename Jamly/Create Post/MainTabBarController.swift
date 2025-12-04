//
//  MainTabBarController.swift
//  Jamly
//
//  Created by Mitra, Monita on 10/21/25.
//

import UIKit

class MainTabBarController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if (viewController.title == "createPostTemp") {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let createPostVC = storyboard.instantiateViewController(identifier: "CreatePostVC")
            
            createPostVC.modalPresentationStyle = .fullScreen
            present(createPostVC, animated: true, completion: nil)
            
            return false
        }
        return true
    }
    
}
