import UIKit
import CoreML
import Vision
import ImageIO
import os.log
import Alamofire
import SwiftyJSON
import PopupDialog

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    //MARK: Properties
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var classLabelView: UITextView!
    
    @IBOutlet weak var overlayView: OverlayView!
    
    /*
     This value is passed by `ViewController` in `processImage(_ image: UIImage)`
     */
    var food: Food?
    var foodTypes = [Food]()
    
    // MARK: Controllers that manage functionality
    private var result: Result?
    private let predictionModel: Food101 = Food101()
    private let modelDataHandler: ModelDataHandler? = ModelDataHandler(modelFileName: "detect", labelsFileName: "labelmap", labelsFileExtension: "txt")
    private var inferenceViewController: InferenceViewController?
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.layer.zPosition = 1
        overlayView.layer.zPosition = 5
        // Do any additional setup after loading the view, typically from a nib.
        classLabelView.isEditable = false
        classLabelView.text = "Please take a photo or choose from the album"
    }
    
    @IBAction func takePicture(_ sender: Any) {
        // Remove all existing food types and drawed boundaries
        foodTypes.removeAll()
        overlayView.setNeedsDisplay()
        let objectOverlays: [ObjectOverlay] = []
        draw(objectOverlays: objectOverlays)
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        present(picker, animated: true)
    }
    
    @IBAction func chooseImage(_ sender: Any) {
        // Remove all existing food types and drawed boundaries
        foodTypes.removeAll()
        overlayView.setNeedsDisplay()
        let objectOverlays: [ObjectOverlay] = []
        draw(objectOverlays: objectOverlays)
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .savedPhotosAlbum
        present(picker, animated: true)
    }
     
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        picker.dismiss(animated: true)
        classLabelView.text = "Analyzing Image..."
//        classificationLabel.text = "Analyzing Image…"
        
        guard let uiImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage
            else { fatalError("No image from image picker") }
        
        imageView.image = uiImage
        
        // runModelnil
        let reziedImage = uiImage.resize(to: CGSize(width: 300, height: 300))!
        guard let modelPixelBuffer = reziedImage.to32BGRAPixelBuffer() else {
            fatalError("Scaling or converting to 32BGRA pixel buffer failed!")
        }
        runModel(onPixelBuffer: modelPixelBuffer, uiImage: uiImage)

    }
    
    
    // MARK: Run model and process the image
    
    /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
     */
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer, uiImage inputImage: UIImage) {
        
        self.modelDataHandler?.set(numberOfThreads: 3)
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)
        
        guard let displayResult = result else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        DispatchQueue.main.async {
            
            // Display results by handing off to the InferenceViewController
            self.inferenceViewController?.resolution = CGSize(width: width, height: height)
            
            var inferenceTime: Double = 0
            if let resultInferenceTime = self.result?.inferenceTime {
                inferenceTime = resultInferenceTime
            }
            self.inferenceViewController?.inferenceTime = inferenceTime
            self.inferenceViewController?.tableView.reloadData()
            
            // Draws the bounding boxes and displays class names and confidence scores.
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)), inputImage: inputImage)
        }
    }
    
    /**
     This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
     */
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize, inputImage inputImg: UIImage) {

        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()

        guard !inferences.isEmpty else {
            return
        }

        var objectOverlays: [ObjectOverlay] = []
        var foodCounter: Int = 1

        for inference in inferences {
            // Translates bounding box rect to current view.
            var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))


            if convertedRect.origin.x < 0 {
                convertedRect.origin.x = self.edgeOffset
            }

            if convertedRect.origin.y < 0 {
                convertedRect.origin.y = self.edgeOffset
            }

            if convertedRect.maxY > self.overlayView.bounds.maxY {
                convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
            }

            if convertedRect.maxX > self.overlayView.bounds.maxX {
                convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
            }
            
            
//            let confidenceValue = Int(inference.confidence * 100.0)
            let string = "\(foodCounter)"
//            let string = "
            
            let size = string.size(usingFont: self.displayFont)

            let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)

            objectOverlays.append(objectOverlay)
            
            let croppedImage = cropImage(inputImage: inputImg, cropRect: convertedRect)!
            processImage(croppedImage, foodCounter)
            foodCounter += 1
        }

        // Hands off drawing to the OverlayView
        self.draw(objectOverlays: objectOverlays)

    }
    
    func cropImage(inputImage: UIImage, cropRect: CGRect) -> UIImage? {
        let resizedImg = inputImage.resize(to: CGSize(width: self.overlayView.bounds.width, height: self.overlayView.bounds.height))!
        
        let cropZone = CGRect(x: cropRect.origin.x * 2,
                              y: cropRect.origin.y * 2,
                              width: cropRect.size.width * 2,
                              height: cropRect.size.height * 2)
        
        guard let cutImageRef: CGImage = resizedImg.cgImage?.cropping(to: cropZone) else {
            return nil
        }
        
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef)
        return croppedImage
    }
    
    
    func processImage(_ image: UIImage, _ foodCounter: Int) {
//        let model = Food101()
        let size = CGSize(width: 299, height: 299)
        
        guard let buffer = image.resize(to: size)?.pixelBuffer() else {
            fatalError("Scaling or converting to pixel buffer failed!")
        }
        
//        guard let result = try? model.prediction(image: buffer) else {
//            fatalError("Prediction failed!")
//        }
        
        guard let result = try? predictionModel.prediction(image: buffer) else {
            fatalError("Prediction failed!")
        }
        
        
        let confidence = result.foodConfidence["\(result.classLabel)"]! * 100.0
        let converted = String(format: "%.2f", confidence)
        
        
        // Optimize food label and reqeust nutrient info
        let foodLabel = result.classLabel.replacingOccurrences(of: "_", with: " ")
        requestInfo(query: foodLabel) {(calories: Int) in
            self.food = Food(type: foodLabel.capitalized, calories: Double(calories))
            self.foodTypes.append(Food(type: foodLabel.capitalized, calories: Double(calories))!)
            
            //            self.classificationLabel.text = "\(foodLabel.capitalized) - \(converted) % - \(calories) kcal/100g \n"
            if (self.classLabelView.text == "Analyzing Image...") {
                self.classLabelView.text = ""
            }
            self.classLabelView.text += "\(foodCounter): \(foodLabel.capitalized) - \(converted) % - \(calories) kcal/100g \n"
        }
    }
    
    
    func requestInfo(query: String, completion: @escaping (_ result: Int) -> Void) {
        let api_key = "VeMvPDjbDKRFidJmUe94wYSsO9y1f5r3VEcKcYXT"
        
        let queryParams: [String: String] = [
            "format": "json",
            "api_key": api_key,
            "nutrients": "208",
            "q": query,
            "sort": "n",
            "max": "3",
            "offset": "0"
        ]
        Alamofire.request("https://api.nal.usda.gov/ndb/search/", method: .get, parameters: queryParams).responseJSON { (response) in
            if response.result.isSuccess {
                let foodJSON: JSON = JSON(response.result.value!)
                let ndbno = foodJSON["list"]["item"][0]["ndbno"].stringValue
                print(ndbno)
                
                let nutrientParams: [String: String] = [
                    "format" : "json",
                    "api_key": api_key,
                    "ndbno": ndbno,
                    "nutrients": "208"
                ]
                Alamofire.request("https://api.nal.usda.gov/ndb/nutrients/", method: .get, parameters: nutrientParams).responseJSON { (response) in
                    if response.result.isSuccess {
                        let nutrientJSON: JSON = JSON(response.result.value!)
                        // Return calorie value per 100g of the food
                        completion(nutrientJSON["report"]["foods"][0]["nutrients"][0]["gm"].intValue)
                    }
                }
            }
        }
    }
    
    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    func draw(objectOverlays: [ObjectOverlay]) {
        print("drawing...!!!")
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.setNeedsDisplay()
    }
    
    
    //MARK: - Navigation
    
    // Do a little preparation before navigation
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "measureSize" {
            if (food == nil) {
                let alert = UIAlertController(title: "Alert", message: "No photo chosen.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                    NSLog("The \"OK\" alert occured.")
                }))
                self.present(alert, animated: true, completion: nil)
                return false
            } else {
                os_log("Food is set. Continue to calculate calories", log: OSLog.default, type: .debug)
                return true
            }
        }
        // by default, transition
        return true
    }
    
    @IBAction func measureSize(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "measureSize", sender: food)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "measureSize" {
            let nextScene = segue.destination as! GameViewController
            nextScene.food = food
        }
    }
    
    @IBAction func chooseFood(_ sender: UIBarButtonItem) {
        if foodTypes.count == 0 {
            // Prepare the popup
            let title = "No Food Available"
            let message = "You need to have at least one food recognized to continue!"
            
            // Create the dialog
            let popup = PopupDialog(title: title,
                                    message: message,
                                    buttonAlignment: .horizontal,
                                    transitionStyle: .zoomIn,
                                    tapGestureDismissal: true,
                                    panGestureDismissal: true,
                                    hideStatusBar: true) {
                                        print("Completed")
            }
            
            // Create OK button
            let buttonOK = DefaultButton(title: "OK") {
                print("Clicked OK button")
            }
            
            // Add buttons to dialog
            popup.addButtons([buttonOK])
            
            // Present dialog
            self.present(popup, animated: true, completion: nil)
        } else {
            // Prepare the popup assets
            let title = "Please select a food type"
            let message = "You must select a food type to continue to use AR to measure food size"
            let image = UIImage(named: "pexels-photo-103290")
            
            // Create the dialog
            let popup = PopupDialog(title: title, message: message, image: image)
            
            var buttonList = [DefaultButton]()
            // Create button
            for food in foodTypes {
                let button = DefaultButton(title: food.type, height: 60) {
                    self.food = food
                    self.performSegue(withIdentifier: "measureSize", sender: self.food)
                }
                buttonList.append(button)
            }
            
            let cancelButton = CancelButton(title: "Cancel") {
                print("You canceled the car dialog.")
            }
            
            // Add buttons to dialog
            // Alternatively, you can use popup.addButton(buttonOne) to add a single button
            popup.addButtons(buttonList)
            popup.addButtons([cancelButton])
            
            // Present dialog
            self.present(popup, animated: true, completion: nil)
        }

    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
