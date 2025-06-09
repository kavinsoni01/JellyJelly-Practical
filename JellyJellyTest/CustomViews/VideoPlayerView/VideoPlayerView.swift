//
//  VideoPlayerView.swift
//  TagViewDemo
//
//  Created by Jiguar MacBookPro on 06/06/25.
//

import UIKit
import AVFoundation

class VideoPlayerView: UIView {
    
    // MARK: - Properties
    var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?
    private var playerItemObserver: NSKeyValueObservation?
    
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .black
    }
        
    // MARK: - Configuration
    func configure(with url: URL) {
        DispatchQueue.main.async { [weak self] in
            Loader.shared.showLoader()
        }
        
        prepareToPlay(url: url)
    }
    
    private func prepareToPlay(url: URL) {
        // Clean up previous player
        cleanupPlayer()
        
        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = true
        
        setupPlayerLayer()
        setupObservers()
    }
    
    private func setupPlayerLayer() {
        playerLayer?.removeFromSuperlayer()
        
        playerLayer = AVPlayerLayer(player: player)
        guard let playerLayer = playerLayer else { return }
        
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = bounds
        layer.insertSublayer(playerLayer, at: 0)
    }
    
    private func setupObservers() {
        // Observe player item status
        playerItemObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] (item, _) in
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self?.handlePlayerReady()
                }
            }
        }
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }
    
    // MARK: - Player Events
    @objc private func playerItemDidReachEnd(notification: Notification) {
        player?.seek(to: .zero)
        player?.play()
    }
    
    private func handlePlayerReady() {
        DispatchQueue.main.async { [weak self] in
            self?.safeStopActivityIndicator()
            self?.play()
        }
    }
    
    // MARK: - Activity Indicator Safety
    private func safeStopActivityIndicator() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.safeStopActivityIndicator()
            }
            return
        }
        
        Loader.shared.hideLoader()
    }
    
    // MARK: - Player Controls
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func toggleMute() {
        player?.isMuted.toggle()
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    // MARK: - Cleanup
    private func cleanupPlayer() {
        player?.pause()
        playerItemObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        playerItem = nil
    }
    
    deinit {
        cleanupPlayer()
        safeStopActivityIndicator()
    }
}
