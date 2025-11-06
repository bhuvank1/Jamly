//
//  PostDetailViewController.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/3/25.
//

import UIKit

class PostDetailViewController: UIViewController, UIScrollViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    var contentView: UIContentView!
    var postImageView: UIImageView!
    @IBOutlet weak var captionTextView: UITextView!
    
    @IBOutlet weak var likesCount: UIButton!
    @IBOutlet weak var commentCount: UIButton!
    @IBOutlet weak var ratingLabel: UILabel!
    var post: Post?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        captionTextView.text = post?.caption
        let tempRating = String(post?.rating ?? 0)
        ratingLabel.text = String("\(tempRating)/5")
        commentCount.setTitle(String(post?.comments.count ?? 0), for: .normal)
        likesCount.setTitle(String(post?.likes.count ?? 0), for: .normal)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "likesSegue",
           let destVC = segue.destination as? LikeViewController {
            destVC.likes = post?.likes ?? []
        } else if segue.identifier == "commentsSegue",
                  let destVC = segue.destination as? CommentsViewController {
            destVC.comments = post?.comments ?? []
        }
    }
    

}
