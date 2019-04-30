import ARKit
import LBTAComponents

class GameViewController: UIViewController, ARSCNViewDelegate, UINavigationControllerDelegate {
    
    let arView: ARSCNView = {
        let view = ARSCNView()
        return view
    }()

    var startingPositionNode: SCNNode?
    var endingPositionNode: SCNNode?
    
    var distances = [Float]()
    var calorieCount = Float(0.0)
    var state = "Not Ready!"
    
    var food: Food?
    var type: String?
    var caloriesPerUnit: Double?
    
    // MARK: Buttons
    @objc func handleCancelButtonTapped() {
        let isPresentingInSizeMeasurementMode = presentingViewController is UINavigationController
        
        if isPresentingInSizeMeasurementMode {
            dismiss(animated: true, completion: nil)
        }
        else if let owningNavigationController = navigationController {
            owningNavigationController.popViewController(animated: true)
        }
        else {
            fatalError("The GameViewController is not inside a navigation controller.")
        }
    }

    // Plus: add a dimension size
    let plusButtonWidth = ScreenSize.width * 0.1
    lazy var plusButton: UIButton = {
        var button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "PlusButton").withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = UIColor(white: 1.0, alpha: 0.7)
        button.layer.cornerRadius = plusButtonWidth * 0.5
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(handlePlusButtonTapped), for: .touchUpInside)
        button.layer.zPosition = 1
        button.imageView?.contentMode = .scaleAspectFill
        return button
    } ()
    
    /*
    @objc func handlePlusButtonTapped() {
        print("Tapped on plus button")
        if state == "Ready!" {
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            arView.addGestureRecognizer(tapGestureRecognizer)
            addDimensionalDistance()
        } else {
            let noPlaneAlert = UIAlertController(title: "Error", message: "No plane has been detected! Please wait until State is Ready!", preferredStyle: UIAlertControllerStyle.alert)
            noPlaneAlert.addAction(UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction!) in
                print("OK")
            })
            self.present(noPlaneAlert, animated: true)
        }
    }
 */
    
    @objc func handlePlusButtonTapped() {
        print("Tapped on plus button")
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGestureRecognizer)
        addDimensionalDistance()
    }
    
    func addDimensionalDistance() {
        distanceLabel.text = "Distance:"
        startingPositionNode?.removeFromParentNode()
        endingPositionNode?.removeFromParentNode()
        startingPositionNode = nil
        endingPositionNode = nil
    }
    
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
        if startingPositionNode != nil && endingPositionNode != nil {
            let addDimensionalDistanceAlert = UIAlertController(title: "Error", message: "You have tapped twice! Please click on Add Button again!", preferredStyle: UIAlertController.Style.alert)
            addDimensionalDistanceAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
                print("Cancel")
            })
            self.present(addDimensionalDistanceAlert, animated: true)
        } else {
            let tapLocation = sender.location(in: arView)
            let hitTestResults = arView.hitTest(tapLocation, types: .featurePoint)
            if let result = hitTestResults.first {
                //let camera = arView.pointOfView?.worldPosition
                let cameraRelativePosition = SCNVector3(x: 0, y: 0, z: -Float(result.distance))
                if startingPositionNode != nil && endingPositionNode == nil {
                    let sphere = SCNNode(geometry: SCNSphere(radius: 0.002))
                    sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                    Service.addChildNode(sphere, toNode: arView.scene.rootNode, inView: arView, cameraRelativePosition: cameraRelativePosition)
                    endingPositionNode = sphere
                    guard let xDistance = Service.distance3(fromStartingPositionNode: startingPositionNode, onView: arView, cameraRelativePosition: cameraRelativePosition)?.x else {return}
                    guard let yDistance = Service.distance3(fromStartingPositionNode: startingPositionNode, onView: arView, cameraRelativePosition: cameraRelativePosition)?.y else {return}
                    guard let zDistance = Service.distance3(fromStartingPositionNode: startingPositionNode, onView: arView, cameraRelativePosition: cameraRelativePosition)?.z else {return}
                    distanceLabel.text = String(format: "Distance: %.2f", Service.distance(x: xDistance, y: yDistance, z: zDistance)) + "m"
                    distances.append( Service.distance(x: xDistance, y: yDistance, z: zDistance) )
                } else if startingPositionNode == nil && endingPositionNode == nil {
                    let sphere = SCNNode(geometry: SCNSphere(radius: 0.002))
                    sphere.geometry?.firstMaterial?.diffuse.contents = UIColor.purple
                    Service.addChildNode(sphere, toNode: arView.scene.rootNode, inView: arView, cameraRelativePosition: cameraRelativePosition)
                    startingPositionNode = sphere
                }
            }
        }
    }
    
    // Minus: remove a dimension size
    let minusButtonWidth = ScreenSize.width * 0.1
    lazy var minusButton: UIButton = {
        var button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "MinusButton").withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = UIColor(white: 1.0, alpha: 0.7)
        button.layer.cornerRadius = minusButtonWidth * 0.5
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(handleMinusButtonTapped), for: .touchUpInside)
        button.layer.zPosition = 1
        button.imageView?.contentMode = .scaleAspectFill
        return button
    } ()
    
    @objc func handleMinusButtonTapped() {
        print("Tapped on minus button")
        if distances.count == 0 {
            let nilDistanceAlert = UIAlertController(title: "Error", message: "No size has been measured! Please add a dimensional size!", preferredStyle: UIAlertController.Style.alert)
            nilDistanceAlert.addAction(UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction!) in
                print("OK")
            })
            self.present(nilDistanceAlert, animated: true)
        } else {
            distances.remove(at: distances.endIndex-1)
        }
    }
    
    // Reset
    let resetButtonWidth = ScreenSize.width * 0.1
    lazy var resetButton: UIButton = {
        var button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "ResetButton").withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = UIColor(white: 1.0, alpha: 0.7)
        button.layer.cornerRadius = resetButtonWidth * 0.5
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(handleResetButtonTapped), for: .touchUpInside)
        button.layer.zPosition = 1
        button.imageView?.contentMode = .scaleAspectFill
        return button
    } ()
    
    @objc func handleResetButtonTapped() {
        print("Tapped on reset button")
        resetScene()
    }
    
    func resetScene() {
        arView.session.pause()
        arView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }
    
    @objc func handleCheckButtonTapped() {
        print("Tapped on check button")
        calculateCalories()
    }
    
    func calculateCalories() {
        if distances.count == 0 {
            let nilDistanceAlert = UIAlertController(title: "Error", message: "No size has been measured! Please add a dimensional size!", preferredStyle: UIAlertController.Style.alert)
            nilDistanceAlert.addAction(UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction!) in
                print("OK")
            })
            self.present(nilDistanceAlert, animated: true)
        } else if distances.count > 3 {
            let maxDimensionExtendAlert = UIAlertController(title: "Error", message: "Too many dimensional sizes! Maximum three! Press '-' to remove one dimensional size!", preferredStyle: UIAlertController.Style.alert)
            maxDimensionExtendAlert.addAction(UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction!) in
                print("OK")
            })
            self.present(maxDimensionExtendAlert, animated: true)
        } else {
            print(distances)
            calorieCount = distances.reduce(1, { x, y in x * y}) * Float(caloriesPerUnit!)
            print(calorieCount)
            calorieLabel.text = String(format: "Calories: %.2f", calorieCount * 10000)
            distances.removeAll()
        }
    }

    // MARK: Labels
    let typeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = UIColor.black
        label.text = "Food Type: "
        return label
    }()
    
//    let trackingLabel: UILabel = {
//        let label = UILabel()
//        label.font = UIFont.boldSystemFont(ofSize: 20)
//        label.textColor = UIColor.black
//        label.text = "Tracking State:"
//        return label
//    }()
    
    let distanceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = UIColor.black
        label.text = "Distance:"
        return label
    }()
    
    let calorieLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = UIColor.black
        label.text = "Total Calories:"
        return label
    }()
    
    let centerImageView: UIImageView = {
        let view = UIImageView()
        view.image = #imageLiteral(resourceName: "Center")
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    // MARK: View setup
    func setupViews() {
        view.addSubview(arView)
        arView.fillSuperview()
        
        let navBar: UINavigationBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: ScreenSize.width, height: 44))
        self.view.addSubview(navBar)
        let navItem = UINavigationItem(title: "Measure Size")
        let cancelItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: nil, action: #selector(handleCancelButtonTapped))
        let checkItem = UIBarButtonItem(title: "calculate", style: UIBarButtonItem.Style.plain, target: nil, action: #selector(handleCheckButtonTapped))
        navItem.leftBarButtonItem = cancelItem
        navItem.rightBarButtonItem = checkItem
        navBar.setItems([navItem], animated: false)
    
        view.addSubview(plusButton)
        plusButton.anchor(nil, left: view.safeAreaLayoutGuide.leftAnchor, bottom: view.safeAreaLayoutGuide.bottomAnchor, right: nil, topConstant: 0, leftConstant: 24, bottomConstant: 24, rightConstant: 0, widthConstant: plusButtonWidth, heightConstant: plusButtonWidth)
        
        view.addSubview(minusButton)
        minusButton.anchor(nil, left: nil, bottom: view.safeAreaLayoutGuide.bottomAnchor, right: view.safeAreaLayoutGuide.rightAnchor, topConstant: 0, leftConstant: 0, bottomConstant: 24, rightConstant: 24, widthConstant: minusButtonWidth, heightConstant: minusButtonWidth)
        
        view.addSubview(resetButton)
        resetButton.anchor(nil, left: nil, bottom: view.safeAreaLayoutGuide.bottomAnchor, right: nil, topConstant: 0, leftConstant: 0, bottomConstant: 24, rightConstant: 0, widthConstant: resetButtonWidth, heightConstant: resetButtonWidth)
        resetButton.anchorCenterXToSuperview()
        
        view.addSubview(typeLabel)
        typeLabel.anchor(navBar.bottomAnchor, left: view.safeAreaLayoutGuide.leftAnchor, bottom: nil, right: nil, topConstant: 0, leftConstant: 24, bottomConstant: 0, rightConstant: 0, widthConstant: 0, heightConstant: 32)
        
//        view.addSubview(trackingLabel)
//        trackingLabel.anchor(typeLabel.bottomAnchor, left: view.safeAreaLayoutGuide.leftAnchor, bottom: nil, right: nil, topConstant: 0, leftConstant: 24, bottomConstant: 0, rightConstant: 0, widthConstant: 0, heightConstant: 32)
        
        view.addSubview(distanceLabel)
        distanceLabel.anchor(typeLabel.bottomAnchor, left: view.safeAreaLayoutGuide.leftAnchor, bottom: nil, right: nil, topConstant: 0, leftConstant: 24, bottomConstant: 0, rightConstant: 0, widthConstant: 0, heightConstant: 32)
        
        view.addSubview(calorieLabel)
        calorieLabel.anchor(distanceLabel.bottomAnchor, left: view.safeAreaLayoutGuide.leftAnchor, bottom: nil, right: nil, topConstant: 0, leftConstant: 24, bottomConstant: 0, rightConstant: 0, widthConstant: 0, heightConstant: 32)
 
        view.addSubview(centerImageView)
        centerImageView.anchorCenterSuperview()
        centerImageView.anchor(nil, left: nil, bottom: nil, right: nil, topConstant: 0, leftConstant: 0, bottomConstant: 0, rightConstant: 0, widthConstant: ScreenSize.width * 0.05, heightConstant: ScreenSize.width * 0.05)
        
        typeLabel.text = String("Type: " + food!.type)
    }
    
    // MARK: AR Session
    let configuration = ARWorldTrackingConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        caloriesPerUnit = food!.calories
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [])
        arView.debugOptions = [SCNDebugOptions.showFeaturePoints, SCNDebugOptions.showWorldOrigin]
        arView.autoenablesDefaultLighting = true
        arView.delegate = self
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func createFloor(anchor: ARPlaneAnchor) -> SCNNode {
        let floor = SCNNode()
        //floor.name = name
        floor.eulerAngles = SCNVector3(90.degreesToRadians,0,0)
        floor.geometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        //floor.geometry?.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "Material")
        //floor.opacity = 0.01
        //''''floor.geometry?.firstMaterial?.isDoubleSided = true
        floor.position = SCNVector3(anchor.center.x, anchor.center.y, anchor.center.z)
        return floor
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
//            self.trackingLabel.text = "Tracking:" + self.getTrackigDescription()
        }
    }
    
    var trackingState: ARCamera.TrackingState!
    func getTrackigDescription() -> String {
        var description = ""
        if let t = trackingState {
            switch(t) {
            case .notAvailable:
                description = "TRACKING UNAVAILABLE"
            case .normal:
                description = "TRACKING NORMAL"
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    description = "TRACKING LIMITED - Too much camera movement"
                case .insufficientFeatures:
                    description = "TRACKING LIMITED - Not enough surface detail"
                case .initializing:
                    description = "INITIALIZING"
                case .relocalizing:
                    description = "RELOCALIZING"
                }
            }
        }
        return description
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        trackingState = camera.trackingState
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchorPlane = anchor as? ARPlaneAnchor else { return }
        print("New Plane Anchor found at extent:", anchorPlane.extent)
        let floor = createFloor(anchor: anchorPlane)
        node.addChildNode(floor)
        state = "Ready!"
    }
    
    func removeNode(named: String) {
        arView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == named {
                node.removeFromParentNode()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let anchorPlane = anchor as? ARPlaneAnchor else { return }
        //print("Plane Anchor updated with extent:", anchorPlane.extent)
        removeNode(named: "floor")
        let floor = createFloor(anchor: anchorPlane)
        node.addChildNode(floor)
        state = "Ready!"
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let anchorPlane = anchor as? ARPlaneAnchor else { return }
        print("Plane Anchor removed with extent:", anchorPlane.extent)
        removeNode(named: "floor")
        state = "Not Ready!"
    }
}

extension SCNVector3 {
    static func positionFrom(matrix: matrix_float4x4) -> SCNVector3 {
        let column = matrix.columns.3
        return SCNVector3(column.x, column.y, column.z)
    }
}
