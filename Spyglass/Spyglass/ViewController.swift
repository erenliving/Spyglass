//
//  ViewController.swift
//  Spyglass
//
//  Created by Eren Livingstone on 2018-03-10.
//  Copyright © 2018 Eren Livingstone. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate
{
    @IBOutlet var sceneView: ARSCNView!
	
	var visionRequests = [VNRequest]()
    
    override func viewDidLoad()
	{
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
		
		guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model) else
		{
			fatalError("Could not load InceptionV3 CoreML model")
		}
		
		let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
		classificationRequest.imageCropAndScaleOption = .centerCrop
		visionRequests = [classificationRequest]
    }
    
    override func viewWillAppear(_ animated: Bool)
	{
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool)
	{
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning()
	{
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error)
	{
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession)
	{
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession)
	{
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
	
	// MARK: - VisionCoreMLRequest handler
	
	func handleClassifications(request: VNRequest, error: Error?)
	{
		guard error == nil else
		{
			print("Classification error: \(error!.localizedDescription)")
			return
		}
		
		guard let observations = request.results else
		{
			print("Classification: no results")
			return
		}
		
		let classifications = observations[0...4] // top 4 results
			.flatMap({ $0 as? VNClassificationObservation })
			.map({ "\($0.identifier) \(($0.confidence * 100.0).rounded())" })
			.joined(separator: "\n")
		
		DispatchQueue.main.async
		{
			// TODO: self.resultView.text = classifications
		}
	}
}
