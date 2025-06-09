//
//  CameraRollCell.swift
//  TagViewDemo
//
//  Created by Jiguar MacBookPro on 06/06/25.
//

import UIKit
import Photos

protocol CameraRollCellDelegate: AnyObject {
    func cameraRollCellDidTapDelete(_ cell: CameraRollCell)
}

class CameraRollCell: UICollectionViewCell {
    
    static let identifier = "CameraRollCell"
    
    @IBOutlet weak var viewBack: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var deleteButton: UIButton!
    
    var representedAssetIdentifier: String?
    weak var delegate: CameraRollCellDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        commonSetup()
    }

    private func commonSetup() {
        contentView.layer.masksToBounds = false
        contentView.clipsToBounds = false

        if let viewBack {
            viewBack.addDropShadow()
            viewBack.layer.cornerRadius = 10
            viewBack.clipsToBounds = true
        }
        
        if let thumbnailImageView {
             thumbnailImageView.contentMode = .scaleAspectFill
             thumbnailImageView.clipsToBounds = true
        }
 
        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.main.scale

        if let deleteButton {
            deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
            deleteButton.tintColor = .white
            deleteButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let containerView, let viewBack {
            containerView.layer.shadowPath = UIBezierPath(roundedRect: viewBack.bounds, cornerRadius: viewBack.layer.cornerRadius).cgPath
        }
    
        if let deleteButton, deleteButton.frame.width > 0 {
             deleteButton.layer.cornerRadius = deleteButton.frame.width / 2
             deleteButton.clipsToBounds = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        representedAssetIdentifier = nil
    }

    func configure(with asset: PHAsset, imageManager: PHCachingImageManager, targetSize: CGSize) {
        representedAssetIdentifier = asset.localIdentifier
        thumbnailImageView.image = nil
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            guard let self, self.representedAssetIdentifier == asset.localIdentifier else {
                return
            }
            self.thumbnailImageView.image = image
        }
    }

    @objc private func deleteButtonTapped() {
        delegate?.cameraRollCellDidTapDelete(self)
    }
}

