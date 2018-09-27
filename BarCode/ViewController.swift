//
//  ViewController.swift
//  BarCode
//
//  Created by Fabian Romero Sotelo on 26/09/18.
//  Copyright © 2018 Fabian Romero Sotelo. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate{

    @IBOutlet var sceneView: ARSCNView!
    
    var qrRequests = [VNRequest]()
    var detectedDataAnchor: ARAnchor?
    var processing = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        startQrCodeDetection()
    }
    
    func startQrCodeDetection() {
        // Create a Barcode Detection Request
        let request = VNDetectBarcodesRequest(completionHandler: self.requestHandler)
        // Set it to recognize QR code only
        request.symbologies = [.QR]
        self.qrRequests = [request]
    }
    
    func requestHandler(request: VNRequest, error: Error?) {
        // Get the first result out of the results, if there are any
        if let results = request.results, let result = results.first as? VNBarcodeObservation {
            guard let payload = result.payloadStringValue else {return}
            // Get the bounding box for the bar code and find the center
            var rect = result.boundingBox
            // Flip coordinates
            rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
            rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
            // Get center
            let center = CGPoint(x: rect.midX, y: rect.midY)
            
            DispatchQueue.main.async {
                self.hitTestQrCode(center: center)
                self.processing = false
            }
        } else {
            self.processing = false
        }
    }

    func hitTestQrCode(center: CGPoint) {
        if let hitTestResults = sceneView?.hitTest(center, types: [.featurePoint] ),
            let hitTestResult = hitTestResults.first {
            if let detectedDataAnchor = self.detectedDataAnchor,
                let node = self.sceneView.node(for: detectedDataAnchor) {
                let previousQrPosition = node.position
                node.transform = SCNMatrix4(hitTestResult.worldTransform)
                
            } else {
                // Create an anchor. The node will be created in delegate methods
                self.detectedDataAnchor = ARAnchor(transform: hitTestResult.worldTransform)
                self.sceneView.session.add(anchor: self.detectedDataAnchor!)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if self.processing {
                    return
                }
                self.processing = true
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                options: [:])
                // Process the request
                try imageRequestHandler.perform(self.qrRequests)
            } catch {
                
            }
        }
    }

    // MARK: - ARSCNViewDelegate
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if self.detectedDataAnchor?.identifier == anchor.identifier {
            let sphere = SCNSphere(radius: 1.0)
            sphere.firstMaterial?.diffuse.contents = UIColor.red
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.transform = SCNMatrix4(anchor.transform)
            return sphereNode
        }
        return nil
    }
}
