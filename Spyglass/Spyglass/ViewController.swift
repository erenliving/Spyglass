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
	@IBOutlet var classificationsTextView: UITextView!
	
	let dispatchQueueCoreML = DispatchQueue(label: "com.eren.Spyglass.dispatchQueueCoreML")
	
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
		
		// Begin main loop
		loopCoreMLUpdate()
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
	
	// MARK: - Main loop
	
	func loopCoreMLUpdate()
	{
		// Dispatch CoreML update requests to prevent UI frame rate drops, it will update the UI when it's ready
		dispatchQueueCoreML.async
		{
			self.updateCoreML()
			
			self.loopCoreMLUpdate()
		}
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
		
		let classifications = observations[0...2] // Top 2 results
			.flatMap({ $0 as? VNClassificationObservation })
			.map({ "\($0.identifier) - \(String(format: "%.2f", $0.confidence))" })
			.joined(separator: "\n")
		
		DispatchQueue.main.async
		{
			self.classificationsTextView.text = classifications
		}
	}
	
	// MARK: - CoreML
	
	func updateCoreML()
	{
		// Grab the ARSession's current frame and convert to RGB CIImage
		// Note: not totally sure this image is actually RGB, but seems to work with InceptionV3
		// Note 2: Not sure if image should be rotated before going to the image request (not sure how to handle this, get the device rotation from the ARSession?)
		guard let pixbuff = sceneView.session.currentFrame?.capturedImage else
		{
			assertionFailure("Could not capture current ARKit frame")
			return
		}
		
		let ciImage = CIImage(cvPixelBuffer: pixbuff)
		
		// Prepare CoreML Vision request
		let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
		
		// Run the request using the CoreML model (visionRequests) to classify what it sees in the image
		do
		{
			try imageRequestHandler.perform(self.visionRequests)
		}
		catch
		{
			print("Error starting imageRequestHandler: \(error)")
		}
	}
}
