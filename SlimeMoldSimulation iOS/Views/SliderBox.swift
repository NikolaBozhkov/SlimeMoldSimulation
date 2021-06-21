//
//  SliderBox.swift
//  ElasticString iOS
//
//  Created by Nikola Bozhkov on 3.10.20.
//

import UIKit

protocol SliderBoxDelegate {
    func didUpdate()
}

class SliderBox: UIView {
    
    var delegate: SliderBoxDelegate?
    
    private let fontSize: CGFloat = 17
    private let highlightColor = UIColor([1.0, 0.5, 0.188])
    private let transitionDuration: TimeInterval = 0.25
    private let indicatorInactiveAlpha: CGFloat = 0.8
    
    private let step: Float
    private let format: String
    private let minValue: Float
    private let maxValue: Float
    private let defaultValue: Float
    private(set) var currentValue: Float {
        didSet {
            currentValue = simd_clamp(currentValue, minValue, maxValue)
            valueLabel.text = String(format: format, currentValue)
            updateLineIndicatorPosition()
        }
    }
    
    private var highlightAnimGroup: CAAnimationGroup
    
    private var indicatorCenterXConstraint: NSLayoutConstraint!
    
    lazy var label: UILabel = {
        createLabel()
    }()
    
    lazy var valueLabel: UILabel = {
        let label = createLabel()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    lazy var pctIndicatorLine: UIView = {
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = highlightColor.withAlphaComponent(indicatorInactiveAlpha)
        return line
    }()
    
    init(label: String, minValue: Float, maxValue: Float, defaultValue: Float, format: String = "%.3f", step: Float = 0.0) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.step = step
        self.format = format
        currentValue = defaultValue
        
        let backgroundColor = UIColor(white: 1.0, alpha: 0.19)
        
        let borderColorAnim = CABasicAnimation(keyPath: "borderColor")
        borderColorAnim.fromValue = highlightColor.cgColor
        borderColorAnim.toValue = UIColor.clear.cgColor
        
        let backgroundColorAnim = CABasicAnimation(keyPath: "backgroundColor")
        backgroundColorAnim.fromValue = UIColor.clear.cgColor
        backgroundColorAnim.toValue = backgroundColor.cgColor
        
        highlightAnimGroup = CAAnimationGroup()
        highlightAnimGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        highlightAnimGroup.duration = transitionDuration
        highlightAnimGroup.fillMode = .forwards
        highlightAnimGroup.isRemovedOnCompletion = false
        highlightAnimGroup.animations = [borderColorAnim, backgroundColorAnim]
        
        super.init(frame: .zero)
        
        isUserInteractionEnabled = true
        translatesAutoresizingMaskIntoConstraints = false
        
        layer.cornerRadius = 5
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor
        layer.backgroundColor = backgroundColor.cgColor
        
        self.label.text = label
        valueLabel.text = String(format: format, currentValue)
        
        let stack = UIStackView(arrangedSubviews: [self.label, valueLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fill
        
        let padding: CGFloat = 10
        stack.spacing = padding
        
        addSubview(pctIndicatorLine)
        addSubview(stack)
        
        stack.fill(self, insets: UIEdgeInsets(top: 7, left: 10, bottom: 7, right: 10))
        
        setPctLineIndicatorConstraints()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(reset))
        tapGestureRecognizer.numberOfTapsRequired = 2
        tapGestureRecognizer.delaysTouchesBegan = false
        tapGestureRecognizer.delaysTouchesEnded = false
        tapGestureRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: label.intrinsicContentSize.width + valueLabel.intrinsicContentSize.width,
               height: label.intrinsicContentSize.height)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLineIndicatorPosition()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        showIndicators()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchPosition = touches.first!.location(in: self)
        let pctOffset = max(0.0, min(touchPosition.x / bounds.width, 1.0))
        
        let newValue = minValue + Float(pctOffset) * (maxValue - minValue)
        
        if step == 0 {
            currentValue = newValue
        } else {
            currentValue = round(newValue / step) * step
        }
        
        delegate?.didUpdate()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        hideIndicators()
    }
    
    @objc func reset() {
        currentValue = defaultValue
    }
    
    private func updateLineIndicatorPosition() {
        let progress = CGFloat((currentValue - minValue) / (maxValue - minValue))
        indicatorCenterXConstraint.constant = layer.borderWidth / 2 + progress * (bounds.width - layer.borderWidth)
    }
    
    private func setPctLineIndicatorConstraints() {
        pctIndicatorLine.widthAnchor.constraint(equalToConstant: 2).isActive = true
        pctIndicatorLine.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1.23).isActive = true
        pctIndicatorLine.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        indicatorCenterXConstraint = pctIndicatorLine.centerXAnchor.constraint(equalTo: leadingAnchor)
        indicatorCenterXConstraint.isActive = true
        
        pctIndicatorLine.layer.cornerRadius = 1
    }
    
    private func createLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: fontSize)
        label.textColor = .white
        return label
    }
    
    private func showIndicators() {
        animateHighlight(isOn: true)
    }
    
    private func hideIndicators() {
        animateHighlight(isOn: false)
    }
    
    private func animateHighlight(isOn: Bool) {
        highlightAnimGroup.flipAll()
        layer.add(highlightAnimGroup, forKey: nil)
        
        animateLabel(label, isHighlighted: isOn)
        animateLabel(valueLabel, isHighlighted: isOn)
        
        UIView.animate(withDuration: transitionDuration, delay: 0, options: .curveEaseOut, animations: {
            self.pctIndicatorLine.backgroundColor = isOn ? self.highlightColor
                : self.highlightColor.withAlphaComponent(self.indicatorInactiveAlpha)
        })
    }
    
    private func animateLabel(_ label: UILabel, isHighlighted: Bool) {
        UIView.transition(with: label, duration: transitionDuration, options: [.transitionCrossDissolve, .curveEaseOut], animations: {
            label.textColor = isHighlighted ? self.highlightColor : .white
        })
    }
}
