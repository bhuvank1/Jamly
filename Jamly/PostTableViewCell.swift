//
//  PostTableViewCell.swift
//  Jamly
//
//  Created by Mitra, Monita on 11/6/25.
//

import UIKit

class PostTableViewCell: UITableViewCell {

    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var commentsButton: UIButton!
    @IBOutlet weak var likesButton: UIButton!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var postImageView: UIImageView!
    
    @IBOutlet weak var captionText: UITextView!
    var delegate: UIViewController?
    
    var post: Post? {
        didSet {
                
                // Add double tap gesture only once
                if postImageView.gestureRecognizers?.isEmpty ?? true {
                    let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
                    doubleTap.numberOfTapsRequired = 2
                    doubleTap.cancelsTouchesInView = true
                    postImageView.addGestureRecognizer(doubleTap)
                    postImageView.isUserInteractionEnabled = true
                }
            }
    }
    
   
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        postImageView.isUserInteractionEnabled = true
        
        if postImageView.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) == false {
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
            doubleTap.numberOfTapsRequired = 2
            postImageView.addGestureRecognizer(doubleTap)
            
            // prevents tableView from being double tapped instead
            doubleTap.cancelsTouchesInView = true
        }
        
        selectionStyle = .none
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func commentsButtonTapped(_ sender: Any) {
        if let post = post {
            let otherVC = delegate as! ShowLikesComments
            otherVC.didTapCommentsButton(for: post)
        }
        
    }
    
    @IBAction func likesButtonTapped(_ sender: Any) {
        if let post = post {
            let otherVC = delegate as! ShowLikesComments
            otherVC.didTapLikesButton(for: post)
        }
    }
    
    @IBAction func handleDoubleTap(recognizer: UITapGestureRecognizer) {
        guard let post = post else { return }
        let otherVC = delegate as! ChangeLikes
        otherVC.changeLikes(for: post, cell: self)
    }
}
