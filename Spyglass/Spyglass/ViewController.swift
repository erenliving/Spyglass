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
	let bubbleDepth: Float = 0.01 // The 'depth' of 3D text
	
	var visionRequests = [VNRequest]()
	var latestPrediction = "—" // Contains the latest CoreML prediction
	
	// MARK: - UIViewController
    
    override func viewDidLoad()
	{
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
		
		// Make the text stand out in the scene better
		sceneView.autoenablesDefaultLighting = true
		
		// Add a tap gesture recognizer to identify the object closest to the centre and give it a label
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
		view.addGestureRecognizer(tapGesture)
		
		guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model) else
		{
			fatalError("Could not load selected CoreML model")
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
		
		// Enable plane detection
		configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool)
	{
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
//    override func didReceiveMemoryWarning()
//	{
//        super.didReceiveMemoryWarning()
//        // Release any cached data, images, etc that aren't in use.
//    }
	
	override var prefersStatusBarHidden: Bool
	{
		return false
	}

    // MARK: - ARSCNViewDelegate
	
//	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)
//	{
//		DispatchQueue.main.async
//		{
//			// Update SceneKit here
//		}
//	}
	
    func session(_ session: ARSession, didFailWithError error: Error)
	{
        // Present an error message to the user
		showAlert(withTitle: NSLocalizedString("Session Error", comment: "Session error alert title"), message: NSLocalizedString("Could not start the AR session, please double check the Camera permissions in your Settings. Sorry if error persists", comment: "Session error alert message"))
    }

    func sessionWasInterrupted(_ session: ARSession)
	{
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
		showAlert(withTitle: NSLocalizedString("Session Interrupted", comment: "Session interrupted alert title"), message: NSLocalizedString("The AR session has been interrupted, please wait until it recovers", comment: "Session interrupted alert message"))
    }

//    func sessionInterruptionEnded(_ session: ARSession)
//	{
//        // Reset tracking and/or remove existing anchors if consistent tracking is required
//
//    }
	
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
	
	func updateCoreML()
	{
		// Grab the ARSession's current frame and convert to RGB CIImage
		// Note: not totally sure this image is actually RGB, but seems to work with InceptionV3
		// Note 2: Not sure if image should be rotated before going to the image request (not sure how to handle this, get the device rotation from the ARSession?)
		guard let pixbuff = sceneView.session.currentFrame?.capturedImage else
		{
			return
		}
		
		let ciImage = CIImage(cvPixelBuffer: pixbuff)
		
		// Prepare CoreML Vision request
		let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
		// let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: myOrientation, options: [:]) // Alternatively; we can convert the above to an RGB CGImage and use that. Also UIInterfaceOrientation can inform orientation values.
		
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
			
			// Store the latest prediction
			var objectName = "—"
			objectName = classifications.components(separatedBy: "-")[0]
			objectName = objectName.components(separatedBy: ",")[0]
			self.latestPrediction = objectName
		}
	}
	
	// MARK: - Tap Gesture Recognizer
	
	@objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer)
	{
		let screenCentre = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
		let arHitTestResults = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points
		
		if let closestTapResult = arHitTestResults.first
		{
			let transform = closestTapResult.worldTransform
			let worldCoordinates = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
			
			let node = createNewBubbleParentNode(latestPrediction)
			sceneView.scene.rootNode.addChildNode(node)
			node.position = worldCoordinates
		}
	}
	
	// MARK: - 3D Text
	
	func createNewBubbleParentNode(_ text: String) -> SCNNode
	{
		// Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
		
		// TEXT BILLBOARD CONSTRAINT
		let billboardConstraint = SCNBillboardConstraint()
		billboardConstraint.freeAxes = SCNBillboardAxis.Y
		
		// BUBBLE-TEXT
		let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
		var font = UIFont(name: "Futura", size: 0.15)
		font = font?.withTraits(traits: .traitBold)
		bubble.font = font
		bubble.alignmentMode = kCAAlignmentCenter
		bubble.firstMaterial?.diffuse.contents = UIColor.orange
		bubble.firstMaterial?.specular.contents = UIColor.white
		bubble.firstMaterial?.isDoubleSided = true
		// bubble.flatness // setting this too low can cause crashes.
		bubble.chamferRadius = CGFloat(bubbleDepth)
		
		// BUBBLE NODE
		let (minBound, maxBound) = bubble.boundingBox
		let bubbleNode = SCNNode(geometry: bubble)
		// Centre Node - to Centre-Bottom point
		bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
		// Reduce default text size
		bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
		
		// CENTRE POINT NODE
		let sphere = SCNSphere(radius: 0.005)
		sphere.firstMaterial?.diffuse.contents = UIColor.cyan
		let sphereNode = SCNNode(geometry: sphere)
		
		// BUBBLE PARENT NODE
		let bubbleNodeParent = SCNNode()
		bubbleNodeParent.addChildNode(bubbleNode)
		bubbleNodeParent.addChildNode(sphereNode)
		bubbleNodeParent.constraints = [billboardConstraint]
		
		return bubbleNodeParent
	}
	
	// MARK: - Alerts
	
	func showAlert(withTitle title: String, message: String)
	{
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK alert action title"), style: .default, handler: nil)
		alert.addAction(okAction)
		present(alert, animated: true, completion: nil)
	}
}

// MARK: - UIFont extension

extension UIFont
{
	func withTraits(traits: UIFontDescriptorSymbolicTraits...) -> UIFont
	{
		let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
		return UIFont(descriptor: descriptor!, size: 0)
	}
}
