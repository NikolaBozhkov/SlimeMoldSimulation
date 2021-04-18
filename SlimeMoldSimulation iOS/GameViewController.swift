//
//  GameViewController.swift
//  SlimeMoldSimulation iOS
//
//  Created by Nikola Bozhkov on 13.04.21.
//

import UIKit
import MetalKit

// Our iOS specific view controller
class GameViewController: UIViewController, SettingsViewDelegate {

    var renderer: Renderer!
    var mtkView: MTKView!
    
    @IBOutlet weak var settingsView: SettingsView!
    @IBOutlet weak var fpsLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View of Gameview controller is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }

        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.black

        guard let newRenderer = Renderer(metalKitView: mtkView,
                                         agentCount: Int(settingsView.agentCountSliderBox.currentValue)) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        
        renderer.updateCurrentFps = { fps in
            self.fpsLabel.text = "\(fps) FPS"
        }
        
        settingsView.delegate = self
        invalidateSettings()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(restartSimulation))
        tapGestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(tapGestureRecognizer)
        
        let tapGestureRecognizer1 = UITapGestureRecognizer(target: self, action: #selector(flipSensors))
        tapGestureRecognizer1.numberOfTouchesRequired = 3
        view.addGestureRecognizer(tapGestureRecognizer1)
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: view)
        let locationInSettings = touches.first!.location(in: settingsView)
        
        let triggerSize: CGFloat = 150
        if settingsView.isHidden && location.x < triggerSize {
            settingsView.isHidden = false
        } else if !settingsView.isHidden && !settingsView.bounds.contains(locationInSettings) {
            settingsView.isHidden = true
        }
    }
    
    @objc func restartSimulation() {
        renderer.restartSimulation(agentCount: Int(settingsView.agentCountSliderBox.currentValue))
    }
    
    @objc func flipSensors() {
        renderer.settings.sensorFlip = -renderer.settings.sensorFlip
    }
    
    func invalidateSettings() {
        renderer.settings.simulationSteps = Int(settingsView.simulationStepsSliderBox.currentValue)
        renderer.settings.moveSpeed = settingsView.moveSpeedSliderBox.currentValue
        renderer.settings.sensorOffset = settingsView.sensorOffsetSliderBox.currentValue
        renderer.settings.sensorAngleOffset = .pi * settingsView.sensorAngleOffsetSliderBox.currentValue / 180
        renderer.settings.turnRate = settingsView.turnRateSliderBox.currentValue
//        renderer.settings.depositRate = settingsView.depositRateSliderBox.currentValue
        renderer.settings.diffuseRate = settingsView.diffuseRateSliderBox.currentValue
        renderer.settings.decayRate = settingsView.decayRateSliderBox.currentValue
        renderer.settings.color = [settingsView.colorRSliderBox.currentValue,
                                   settingsView.colorGSliderBox.currentValue,
                                   settingsView.colorBSliderBox.currentValue,
                                   1.0] * settingsView.colorASliderBox.currentValue
    }
}
