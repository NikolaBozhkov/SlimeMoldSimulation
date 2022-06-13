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
        createSliderBox(label: "Agent count", minValue: 1, maxValue: 1000000, defaultValue: 300000, format: "%.0f", step: 1)
    }()
    
    lazy var simulationStepsSliderBox: SliderBox = {
        createSliderBox(label: "Simulation steps", minValue: 1.0, maxValue: 5.0, defaultValue: 3.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var moveSpeedSliderBox: SliderBox = {
        createSliderBox(label: "Move speed", minValue: 0.0, maxValue: 400.0, defaultValue: 50, format: "%.2f")
    }()
    
    lazy var turnRateSliderBox: SliderBox = {
        createSliderBox(label: "Turn rate", minValue: 0.0, maxValue: 5.0, defaultValue: 0.42, format: "%.2f")
    }()
    
    lazy var sensorOffsetSliderBox: SliderBox = {
        createSliderBox(label: "Sensor offset", minValue: 2.0, maxValue: 250.0, defaultValue: 32, format: "%.0f", step: 1.0)
    }()
    
    lazy var sensorAngleOffsetSliderBox: SliderBox = {
        createSliderBox(label: "Sensor angle offset", minValue: 0.0, maxValue: 180.0, defaultValue: 30.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var diffuseRateSliderBox: SliderBox = {
        createSliderBox(label: "Diffuse rate", minValue: 0.0, maxValue: 70.0, defaultValue: 0.0, format: "%.2f")
    }()
    
    lazy var decayRateSliderBox: SliderBox = {
        createSliderBox(label: "Decay rate", minValue: 0.0, maxValue: 3.0, defaultValue: 0.35, format: "%.2f")
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
        createSliderBox(label: "Opacity", minValue: 0.0, maxValue: 0.5, defaultValue: 0.056, format: "%.4f")
    }()
    
    lazy var branchCountSliderBox: SliderBox = {
        createSliderBox(label: "Branch count", minValue: 0.0, maxValue: 10.0, defaultValue: 5.0, format: "%.0f", step: 1.0)
    }()
    
    lazy var branchScaleSliderBox: SliderBox = {
        createSliderBox(label: "Branch scale", minValue: 0.0, maxValue: 10.0, defaultValue: 2.1)
    }()
    
    lazy var libraryButton: UIButton = {
        createButton(withTitle: "Library",
                     image: UIImage(systemName: "folder.fill")?.withTintColor(.white),
                     action: #selector(didTapLibraryButton))
    }()
    
    lazy var saveButton: UIButton = {
        createButton(withTitle: "Save",
                     image: UIImage(systemName: "plus.circle.fill")?.withTintColor(.white),
                     action: #selector(didTapSaveButton))
    }()
    
    lazy var spawnArrangementView: UIView = {
        let label = ViewFactory.newLabel(ofType: .settings)
        label.text = "Spawn arrangement"
        
        let button = createButton(withTitle: "",
                                  image: UIImage(systemName: "aqi.medium")?.withTintColor(.white),
                                  action: #selector(didTapModeButton))
        
        let stack = createStack(from: [label, button], axis: .horizontal)
        stack.distribution = .equalSpacing
        return stack
    }()
    
    lazy var restartButton: UIView = {
        let button = ViewFactory.newButton(withTitle: "Restart simulation",
                                           image: UIImage(systemName: "play.fill")?.withTintColor(.white),
                                           insets: UIEdgeInsets(horizontal: 30, vertical: 7))
//        let stack = createStack(from: [button], axis: .vertical)
//        stack.alignment = .center
        return button
    }()
    
    var isPresetsToggled = false
    var presetsToggleIconImageView: UIImageView?
    lazy var presetsView: UIView = {
        let iconView = UIImageView(image: UIImage(systemName: "play.fill"))
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        
        presetsToggleIconImageView = iconView
        
        let label = ViewFactory.newLabel(ofType: .settings, text: "Presets")
        
        let stack = createStack(from: [iconView, label], axis: .horizontal)
        stack.alignment = .center
        stack.spacing = 7
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapPresetsToggle))
        stack.addGestureRecognizer(tapRecognizer)
        
        let containerStack = createStack(from: [stack], axis: .vertical)
        containerStack.alignment = .leading
        containerStack.layer.cornerRadius = 10
        containerStack.backgroundColor = UIColor(white: 0.0, alpha: 0.2)
        containerStack.isLayoutMarginsRelativeArrangement = true
        containerStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
        
        return containerStack
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
        backgroundColor = UIColor(white: 1, alpha: 0)
        setupBlurEffectView()
        
        let buttonsStack = createStack(from: [libraryButton, saveButton], axis: .horizontal)
        buttonsStack.spacing = 15
        let buttonsStackContainer = createStack(from: [buttonsStack], axis: .vertical)
        buttonsStackContainer.alignment = .leading
        
        let settingsStack = createStack(from: [
            presetsView,
//            buttonsStackContainer,
            agentCountSliderBox,
//            spawnArrangementView,
            restartButton,
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
        
        let containerStack = UIStackView(arrangedSubviews: [settingsStack])
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        containerStack.axis = .horizontal
        containerStack.alignment = .leading
        
        addSubview(containerStack)
        
        containerStack.fill(self, insets: UIEdgeInsets(top: 30, left: 20, bottom: 30, right: 20))
    }
    
    private func setupBlurEffectView() {
        let blurEffect = UIBlurEffect(style: .dark)
        let effectView = UIVisualEffectView(effect: blurEffect)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 12
        effectView.clipsToBounds = true
        addSubview(effectView)
        effectView.fill(self)
    }
    
    private func createSliderBox(label: String, minValue: Float, maxValue: Float,
                                 defaultValue: Float, format: String = "%.3f", step: Float = 0.0) -> SliderBox {
        let sliderBox = SliderBox(label: label, minValue: minValue, maxValue: maxValue,
                                  defaultValue: defaultValue, format: format, step: step)
        sliderBox.delegate = self
        return sliderBox
    }
    
    private func createButton(withTitle title: String, image: UIImage?, action: Selector) -> UIButton {
        let button = ViewFactory.newButton(withTitle: title, image: image, insets: UIEdgeInsets(horizontal: 15, vertical: 7))
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    @objc private func didTapPresetsToggle() {
        isPresetsToggled = !isPresetsToggled
        
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       options: .curveEaseOut) {
            self.presetsToggleIconImageView?.transform = self.isPresetsToggled ? CGAffineTransform(rotationAngle: .pi / 2.0) : .identity
            self.presetsToggleIconImageView?.layoutIfNeeded()
        }
    }
    
    @objc private func didTapModeButton() {
        print("module button tapped")
        // Open selection overlay
    }
    
    @objc private func didTapLibraryButton() {
        
    }
    
    @objc private func didTapSaveButton() {
        
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
