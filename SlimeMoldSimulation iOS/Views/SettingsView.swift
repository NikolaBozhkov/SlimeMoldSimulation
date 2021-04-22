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
    
    lazy var agentCountSliderBox: SliderBox = {
        createSliderBox(label: "Agent Count", minValue: 1, maxValue: 1000000, defaultValue: 1000000, format: "%.0f", step: 1)
    }()
    
    lazy var simulationStepsSliderBox: SliderBox = {
        createSliderBox(label: "Simulation Steps", minValue: 1.0, maxValue: 5.0, defaultValue: 3.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var moveSpeedSliderBox: SliderBox = {
        createSliderBox(label: "Move Speed", minValue: 0.0, maxValue: 400.0, defaultValue: 31.14, format: "%.2f")
    }()
    
    lazy var turnRateSliderBox: SliderBox = {
        createSliderBox(label: "Turn Rate", minValue: 0.0, maxValue: 5.0, defaultValue: 0.49, format: "%.2f")
    }()
    
    lazy var sensorOffsetSliderBox: SliderBox = {
        createSliderBox(label: "Sensor Offset", minValue: 2.0, maxValue: 250.0, defaultValue: 32, format: "%.0f", step: 1.0)
    }()
    
    lazy var sensorAngleOffsetSliderBox: SliderBox = {
        createSliderBox(label: "Sensor Angle Offset", minValue: 0.0, maxValue: 180.0, defaultValue: 30.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var diffuseRateSliderBox: SliderBox = {
        createSliderBox(label: "Diffuse Rate", minValue: 0.0, maxValue: 70.0, defaultValue: 0.0, format: "%.2f")
    }()
    
    lazy var decayRateSliderBox: SliderBox = {
        createSliderBox(label: "Decay Rate", minValue: 0.0, maxValue: 3.0, defaultValue: 0.67, format: "%.2f")
    }()
    
    lazy var colorRSliderBox: SliderBox = {
        createSliderBox(label: "Color R", minValue: 0.0, maxValue: 1.0, defaultValue: 0.814)
    }()
    
    lazy var colorGSliderBox: SliderBox = {
        createSliderBox(label: "Color G", minValue: 0.0, maxValue: 1.0, defaultValue: 0.846)
    }()
    
    lazy var colorBSliderBox: SliderBox = {
        createSliderBox(label: "Color B", minValue: 0.0, maxValue: 1.0, defaultValue: 0.461)
    }()
    
    lazy var colorASliderBox: SliderBox = {
        createSliderBox(label: "Color A", minValue: 0.0, maxValue: 0.5, defaultValue: 0.03, format: "%.4f")
    }()
    
    lazy var branchCountSliderBox: SliderBox = {
        createSliderBox(label: "Branch Count", minValue: 0.0, maxValue: 10.0, defaultValue: 3, format: "%.0f", step: 1.0)
    }()
    
    lazy var branchScaleSliderBox: SliderBox = {
        createSliderBox(label: "Branch Scale", minValue: 0.0, maxValue: 10.0, defaultValue: 5.06)
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
        backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        
        let verticalStack = createStack(from: [
            agentCountSliderBox,
            simulationStepsSliderBox,
            moveSpeedSliderBox,
            turnRateSliderBox,
            sensorOffsetSliderBox,
            sensorAngleOffsetSliderBox,
            diffuseRateSliderBox,
            decayRateSliderBox,
            colorRSliderBox,
            colorGSliderBox,
            colorBSliderBox,
            colorASliderBox,
//            fuelLoadRateSliderBox,
//            fuelConsumptionRateSliderBox,
//            wasteDepositRateSliderBox,
//            wasteConversionRateSliderBox,
//            efficiencySliderBox,
            branchCountSliderBox,
            branchScaleSliderBox,
        ], axis: .vertical)
        
        addSubview(verticalStack)
        
        verticalStack.fill(self, padding: padding)
    }
    
    private func createSliderBox(label: String, minValue: Float, maxValue: Float,
                                 defaultValue: Float, format: String = "%.3f", step: Float = 0.0) -> SliderBox {
        let sliderBox = SliderBox(label: label, minValue: minValue, maxValue: maxValue,
                                  defaultValue: defaultValue, format: format, step: step)
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
