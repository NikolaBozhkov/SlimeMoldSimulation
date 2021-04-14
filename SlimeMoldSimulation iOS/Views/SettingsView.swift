//
//  SettingsView.swift
//  ElasticString iOS
//
//  Created by Nikola Bozhkov on 2.10.20.
//

import UIKit

protocol SettingsViewDelegate {
    func invalidateSettings()
}

class SettingsView: UIView {
    
    private enum SliderBoxPosition {
        case leading, trailing
    }
    
    var delegate: SettingsViewDelegate?
    
    private let padding: CGFloat = 12
    private let margin: CGFloat = 12
    
    lazy var frequencyResponseSliderBox: SliderBox = {
        createSliderBox(label: "Frequency Response", minValue: 0.001, maxValue: 1.0, defaultValue: 0.12)
    }()
    
    lazy var frequencyResponseModSliderBox: SliderBox = {
        createSliderBox(label: "Mod", minValue: -0.2, maxValue: 0.2, defaultValue: 0)
    }()
    
    lazy var dampingRatioSliderBox: SliderBox = {
        createSliderBox(label: "Damping Ratio", minValue: 0.001, maxValue: 1.0, defaultValue: 0.09)
    }()
    
    lazy var dampingRatioModSliderBox: SliderBox = {
        createSliderBox(label: "Mod", minValue: -0.2, maxValue: 0.2, defaultValue: 0)
    }()
    
    lazy var maxOffsetSliderBox: SliderBox = {
        createSliderBox(label: "Max Offset", minValue: 0.0, maxValue: 2.0, defaultValue: 1.0)
    }()
    
    lazy var maxSpringOffsetSliderBox: SliderBox = {
        createSliderBox(label: "Max Spring Offset", minValue: 0.0, maxValue: 2.0, defaultValue: 2.0)
    }()
    
    lazy var pullRadiusSliderBox: SliderBox = {
        createSliderBox(label: "Pull Radius", minValue: 0.0, maxValue: 0.5, defaultValue: 0.07)
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        layer.cornerRadius = 10
        backgroundColor = UIColor(white: 0.15, alpha: 0.85)
        
        frequencyResponseModSliderBox.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let frequencyResponseStackView = createStack(from: [frequencyResponseSliderBox, frequencyResponseModSliderBox], axis: .horizontal)
        
        dampingRatioModSliderBox.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let dampingRatioStackView = createStack(from: [dampingRatioSliderBox, dampingRatioModSliderBox], axis: .horizontal)
        
        let verticalStack = createStack(from: [
            frequencyResponseStackView,
            dampingRatioStackView,
            maxOffsetSliderBox,
            maxSpringOffsetSliderBox,
            pullRadiusSliderBox
        ], axis: .vertical)
        
        addSubview(verticalStack)
        
        verticalStack.fill(self, padding: padding)
        
        frequencyResponseModSliderBox.widthAnchor.constraint(equalTo: frequencyResponseStackView.widthAnchor, multiplier: 0.32).isActive = true
        dampingRatioModSliderBox.widthAnchor.constraint(equalTo: frequencyResponseStackView.widthAnchor, multiplier: 0.32).isActive = true
    }
    
    private func createSliderBox(label: String, minValue: Float, maxValue: Float, defaultValue: Float) -> SliderBox {
        let sliderBox = SliderBox(label: label, minValue: minValue, maxValue: maxValue, defaultValue: defaultValue)
        sliderBox.delegate = self
        return sliderBox
    }
    
    private func createStack(from views: [UIView], axis: NSLayoutConstraint.Axis) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = axis
        stackView.spacing = axis == .horizontal ? 9 : margin
        return stackView
    }
}

extension SettingsView: SliderBoxDelegate {
    func didUpdate() {
        delegate?.invalidateSettings()
    }
}
