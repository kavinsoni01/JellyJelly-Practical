import UIKit

class AnimatedRecordButton: UIButton {
    private let circleLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let centerImageView = UIImageView()
    private let buttonRadius: CGFloat = 32

    var progress: CGFloat = 0.0 {
        didSet {
            progressLayer.strokeEnd = progress
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    private func setupLayers() {
        if circleLayer.superlayer != nil { return }
        // Circle background
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let circlePath = UIBezierPath(arcCenter: center, radius: buttonRadius, startAngle: -.pi/2, endAngle: .pi*3/2, clockwise: true)
        circleLayer.path = circlePath.cgPath
        circleLayer.lineWidth = 6
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor

        progressLayer.path = circlePath.cgPath
        progressLayer.lineWidth = 6
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemRed.cgColor
        progressLayer.strokeEnd = 0
        progressLayer.lineCap = .round

        layer.addSublayer(circleLayer)
        layer.addSublayer(progressLayer)
        // Center icon
        if centerImageView.superview == nil {
            centerImageView.contentMode = .scaleAspectFit
            centerImageView.tintColor = .systemRed
            addSubview(centerImageView)
            centerImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                centerImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                centerImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                centerImageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.44),
                centerImageView.heightAnchor.constraint(equalTo: centerImageView.widthAnchor)
            ])
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure layers always fill bounds and icon is centered
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let circlePath = UIBezierPath(arcCenter: center, radius: buttonRadius, startAngle: -.pi/2, endAngle: .pi*3/2, clockwise: true)
        circleLayer.path = circlePath.cgPath
        progressLayer.path = circlePath.cgPath
    }
    func animateProgress(to value: CGFloat, duration: TimeInterval) {
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = progressLayer.strokeEnd
        anim.toValue = value
        anim.duration = duration
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        progressLayer.add(anim, forKey: "progress")
        progressLayer.strokeEnd = value
    }
    func resetProgress() {
        progressLayer.removeAllAnimations()
        progressLayer.strokeEnd = 0
        progress = 0
    }
    func setCenterImage(_ image: UIImage?) {
        centerImageView.image = image?.withRenderingMode(.alwaysTemplate)
    }
}
