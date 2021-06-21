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

class ColorStack {
    
    lazy var colorRSliderBox: SliderBox = {
        createSliderBox(label: "R", minValue: 0.0, maxValue: 1.0, defaultValue: defaultR)
    }()
    
    lazy var colorGSliderBox: SliderBox = {
        createSliderBox(label: "G", minValue: 0.0, maxValue: 1.0, defaultValue: defaultG)
    }()
    
    lazy var colorBSliderBox: SliderBox = {
        createSliderBox(label: "B", minValue: 0.0, maxValue: 1.0, defaultValue: defaultB)
    }()
    
    lazy var sliderBoxes: [SliderBox] = {
        [colorRSliderBox, colorGSliderBox, colorBSliderBox]
    }()
    
    lazy var stackView: UIStackView = {
        let stack = createStack(from: sliderBoxes, axis: .horizontal)
        stack.distribution = .fillEqually
        return stack
    }()
    
    let delegate: SliderBoxDelegate
    let defaultR: Float
    let defaultG: Float
    let defaultB: Float
    
    init(delegate: SliderBoxDelegate, r: Float = 1.0, g: Float = 1.0, b: Float = 1.0) {
        self.delegate = delegate
        defaultR = r
        defaultG = g
        defaultB = b
    }
    
    private func createSliderBox(label: String, minValue: Float, maxValue: Float,
                                 defaultValue: Float, format: String = "%.3f", step: Float = 0.0) -> SliderBox {
        let sliderBox = SliderBox(label: label, minValue: minValue, maxValue: maxValue,
                                  defaultValue: defaultValue, format: format, step: step)
        sliderBox.delegate = delegate
        return sliderBox
    }
    
    func setDelegate(_ delegate: SliderBoxDelegate) {
        sliderBoxes.forEach { $0.delegate = delegate }
    }
}

private let padding: CGFloat = 20
private let margin: CGFloat = 25

class SettingsView: UIView {
    
    private enum SliderBoxPosition {
        case leading, trailing
    }
    
    var delegate: SettingsViewDelegate?
    
    lazy var agentCountSliderBox: SliderBox = {
        createSliderBox(label: "Agent Count", minValue: 1, maxValue: 1000000, defaultValue: 300000, format: "%.0f", step: 1)
    }()
    
    lazy var simulationStepsSliderBox: SliderBox = {
        createSliderBox(label: "Simulation Steps", minValue: 1.0, maxValue: 5.0, defaultValue: 3.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var moveSpeedSliderBox: SliderBox = {
        createSliderBox(label: "Move Speed", minValue: 0.0, maxValue: 400.0, defaultValue: 50, format: "%.2f")
    }()
    
    lazy var turnRateSliderBox: SliderBox = {
        createSliderBox(label: "Turn Rate", minValue: 0.0, maxValue: 5.0, defaultValue: 0.42, format: "%.2f")
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
        createSliderBox(label: "Decay Rate", minValue: 0.0, maxValue: 3.0, defaultValue: 0.35, format: "%.2f")
    }()
    
    lazy var colorStack: ColorStack = {
        ColorStack(delegate: self, r: 1, g: 1, b: 1)
    }()
    
    lazy var colorStack1: ColorStack = {
        ColorStack(delegate: self, r: 1.0, g: 0.559, b: 0.890)
    }()
    
    lazy var colorStack2: ColorStack = {
        ColorStack(delegate: self, r: 0.814, g: 0.929, b: 0.461)
    }()
    
    lazy var colorStack3: ColorStack = {
        ColorStack(delegate: self, r: 0.9, g: 0.351, b: 0.248)
    }()
    
    lazy var colorASliderBox: SliderBox = {
        createSliderBox(label: "Color A", minValue: 0.0, maxValue: 0.5, defaultValue: 0.056, format: "%.4f")
    }()
    
    lazy var branchCountSliderBox: SliderBox = {
        createSliderBox(label: "Branch Count", minValue: 0.0, maxValue: 10.0, defaultValue: 5.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var branchScaleSliderBox: SliderBox = {
        createSliderBox(label: "Branch Scale", minValue: 0.0, maxValue: 10.0, defaultValue: 2.1)
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
        backgroundColor = UIColor(white: 0.0, alpha: 0.9)
        
        let verticalStack = createStack(from: [
            agentCountSliderBox,
            simulationStepsSliderBox,
            moveSpeedSliderBox,
            turnRateSliderBox,
//            sensorOffsetSliderBox,
//            sensorAngleOffsetSliderBox,
//            diffuseRatesSliderBox,
            decayRateSliderBox,
            colorStack.stackView,
//            colorStack1.stackView,
//            colorStack2.stackView,
//            colorStack3.stackView,
            colorASliderBox,
//            fuelLoadRateSliderBox,
//            fuelConsumptionRateSliderBox,
//            wasteDepositRateSliderBox,
//            wasteConversionRateSliderBox,
//            efficiencySliderBox,
            branchCountSliderBox,
            branchScaleSliderBox,
        ], axis: .vertical)
        
//        addSubview(verticalStack)
        
        let containerStack = UIStackView(arrangedSubviews: [verticalStack])
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.axis = .horizontal
        containerStack.alignment = .leading
        
        addSubview(containerStack)
        
        containerStack.fill(self, insets: UIEdgeInsets(top: 30, left: 20, bottom: 30, right: 20))
    }
    
    private func createSliderBox(label: String, minValue: Float, maxValue: Float,
                                 defaultValue: Float, format: String = "%.3f", step: Float = 0.0) -> SliderBox {
        let sliderBox = SliderBox(label: label, minValue: minValue, maxValue: maxValue,
                                  defaultValue: defaultValue, format: format, step: step)
        sliderBox.delegate = self
        return sliderBox
    }
}

extension SettingsView: SliderBoxDelegate {
    func didUpdate() {
        delegate?.invalidateSettings()
    }
}

private func createStack(from views: [UIView], axis: NSLayoutConstraint.Axis) -> UIStackView {
    let stackView = UIStackView(arrangedSubviews: views)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = axis
    stackView.spacing = axis == .horizontal ? 9 : margin
    return stackView
}
