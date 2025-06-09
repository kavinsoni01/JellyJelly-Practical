//
//  FeedCollectionCell.swift
//  TagViewDemo
//
//  Created by Jiguar MacBookPro on 06/06/25.
//

import UIKit
import AVFoundation

protocol FeedCollectionCellDelegate: AnyObject {
    func didFinishPlayback(cell: FeedCollectionCell)
    func feedCollectionCell(_ cell: FeedCollectionCell, didTapShareForVideo video: JellyVideo)
}

class FeedCollectionCell: UICollectionViewCell {
    
    static let identifier = "FeedCollectionCell"

    @IBOutlet weak var btnView: UIButton!
    @IBOutlet weak var lblView: UILabel!
    @IBOutlet weak var lblShare: UILabel!
    @IBOutlet weak var lblLike: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var viewInfo: UIView!
    @IBOutlet weak var lblUserDescriotion: UILabel!
    @IBOutlet weak var lblUserName: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var viewVideo: VideoPlayerView!
    @IBOutlet weak var likeButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var heartImageView: UIImageView!
    @IBOutlet weak var btnSoundOnOff: UIButton!

    private var video: JellyVideo?
    weak var delegate: FeedCollectionCellDelegate?
    private var isVideoPlaying: Bool = true

    override func awakeFromNib() {
        super.awakeFromNib()
        setupGesture()
        heartImageView.alpha = 0
        updateSoundButton()
        observeVideoEnd()
        viewInfo.alpha = 0
        
        userImage.layer.cornerRadius = userImage.frame.height / 2
        userImage.clipsToBounds = true
        userImage.backgroundColor = .darkGray
    }

    func configure(with video: JellyVideo) {
        self.video = video
        if let urlString = video.content?.url, let url = URL(string: urlString) {
            viewVideo.configure(with: url)
        } else {
            // viewVideo.cleanup()
        }
        updateSoundButton()
        isVideoPlaying = true
        viewInfo.alpha = 0
        
        self.lblLike.text = "\(video.numLikes ?? 0)"
        self.lblTitle.text = video.title ?? "Untitled Video"
        self.lblUserDescriotion.text = video.summary ?? "No summary."
        // self.userImage.image = nil // Placeholder for user image
        // self.userImage.loadImage(from: video.user?.imageURL ?? "") // If initial user info is part of JellyVideo
    }

    func updateUserInfo(with profile: UserModel) {
        print("CELL: Updating user info with profile: \(profile.fullName ?? "N/A")")
        self.lblUserName.text = profile.fullName ?? profile.username ?? "Unknown User"
        
        //avatar Base URL is missing so we can not get avtar image
        if let imageUrlString = profile.avatarLowResURL, let url = URL(string: imageUrlString) {
            // self.userImage.sd_setImage(with: url, placeholderImage: UIImage(named: "defaultProfilePic")) // Example using SDWebImage
            self.userImage.image = UIImage(systemName: "person.circle.fill")
            // TODO: Implement async image loading here
        } else {
            self.userImage.image = UIImage(systemName: "person.circle.fill")
        }
    }

    func resetUserInfo() {
        print("CELL: Resetting user info.")
        if let videoTitle = video?.title, !videoTitle.isEmpty {
            self.lblUserName.text = videoTitle // Fallback to video title or a generic loading state
        } else {
            self.lblUserName.text = "Loading user..."
        }
        self.userImage.image = UIImage(systemName: "person.circle")
    }

    func play() {
        viewVideo.play()
        isVideoPlaying = true
    }

    func pause() {
        viewVideo.pause()
        isVideoPlaying = false
    }

    @IBAction func likeTapped(_ sender: UIButton) {
        animateHeart()
    }

    @IBAction func shareTapped(_ sender: UIButton) {
        guard let videoToShare = self.video else { return }
        delegate?.feedCollectionCell(self, didTapShareForVideo: videoToShare)
    }

    @IBAction func soundOnOffTapped(_ sender: UIButton) {
        viewVideo.toggleMute()
        updateSoundButton()
    }

    private func updateSoundButton() {
        let isMuted = viewVideo.isMuted
        let imageName = isMuted ? "mute" : "volume"
        btnSoundOnOff.setImage(UIImage(named: imageName), for: .normal)
        btnSoundOnOff.accessibilityLabel = isMuted ? "Sound Off" : "Sound On"
    }

    private func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        self.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapForLike(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)

        tap.require(toFail: doubleTap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if isVideoPlaying {
            pause()
        } else {
            play()
        }
        
        UIView.animate(withDuration: 0.3) {
            self.viewInfo.alpha = self.isVideoPlaying ? 0 : 1
        }
    }

    @objc private func handleDoubleTapForLike(_ gesture: UITapGestureRecognizer) {
        animateHeart()
    }

    private func animateHeart() {
        heartImageView.alpha = 1
        heartImageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.heartImageView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.2, options: .curveEaseOut, animations: {
                self.heartImageView.alpha = 0
            })
        }
    }

    private func observeVideoEnd() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying(_:)), name: .AVPlayerItemDidPlayToEndTime, object: viewVideo.player?.currentItem)
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem, playerItem == viewVideo.player?.currentItem else {
            return
        }
        delegate?.didFinishPlayback(cell: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

extension VideoPlayerView {
    var isMuted: Bool {
        get { player?.isMuted ?? true }
    }
}
