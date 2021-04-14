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

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        
        initUI()
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    
    private func initUI() {
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let location = touches.first!.location(in: view)
        
        let triggerSize: CGFloat = 150
        if location.x < triggerSize && location.y < triggerSize {
            settingsView.isHidden = !settingsView.isHidden
        }
    }
    
    func invalidateSettings() {
        
    }
}
