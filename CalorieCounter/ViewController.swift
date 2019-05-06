import UIKit
import CoreML
import Vision
import ImageIO
import os.log
import Alamofire
import SwiftyJSON

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    //MARK: Properties
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var energyPer100g: UILabel!

    @IBOutlet weak var overlayView: OverlayView!
    
    /*
     This value is passed by `ViewController` in `processImage(_ image: UIImage)`
     */
    var food: Food?
    
    // MARK: Controllers that manage functionality
    private var result: Result?
    private let modelDataHandler: ModelDataHandler? = ModelDataHandler(modelFileName: "detect", labelsFileName: "labelmap", labelsFileExtension: "txt")
    private var inferenceViewController: InferenceViewController?
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        classificationLabel.text = "Please take a photo or choose from the album"

    }
    
    @IBAction func takePicture(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        present(picker, animated: true)
    }
    
    @IBAction func chooseImage(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .savedPhotosAlbum
        present(picker, animated: true)
    }
     
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        picker.dismiss(animated: true)
        classificationLabel.text = "Analyzing Image…"
        self.energyPer100g.text = "Energy per 100g: calculating..."
        
        guard let uiImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage
            else { fatalError("No image from image picker") }
        processImage(uiImage)
    }
    
    func processImage(_ image: UIImage) {
        let model = Food101()
        let size = CGSize(width: 299, height: 299)
        
        guard let buffer = image.resize(to: size)?.pixelBuffer() else {
            fatalError("Scaling or converting to pixel buffer failed!")
        }
        
        guard let result = try? model.prediction(image: buffer) else {
            fatalError("Prediction failed!")
        }
        
        
        let confidence = result.foodConfidence["\(result.classLabel)"]! * 100.0
        let converted = String(format: "%.2f", confidence)
        
        imageView.image = image
        
        // runModel
        guard let modelPixelBuffer = image.resize(to: CGSize(width: 300, height: 300))?.to32BGRAPixelBuffer() else {
           fatalError("Scaling or converting to 32BGRA pixel buffer failed!")
        }
        runModel(onPixelBuffer: modelPixelBuffer)
        
        // Optimize food label and reqeust nutrient info
        let foodLabel = result.classLabel.replacingOccurrences(of: "_", with: " ")
        requestInfo(query: foodLabel) {(calories: Int) in
            self.food = Food(type: foodLabel.capitalized, calories: Double(calories))
            self.classificationLabel.text = "\(foodLabel.capitalized) - \(converted) %"
            self.energyPer100g.text = "Energy per 100g: \(calories) kcal"
        }
    }
    
    /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
     */
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
        
        self.modelDataHandler?.set(numberOfThreads: 3)
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)
        
        guard let displayResult = result else {
            return
        }
        print(displayResult)
        
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
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }
    
    /**
     This method takes the results, translates the bounding box rects to the current view, draws the bounding boxes, classNames and confidence scores of inferences.
     */
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {

        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()

        guard !inferences.isEmpty else {
            return
        }

        var objectOverlays: [ObjectOverlay] = []

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

            let confidenceValue = Int(inference.confidence * 100.0)
            let string = "\(inference.className)  (\(confidenceValue)%)"

            let size = string.size(usingFont: self.displayFont)

            let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)

            objectOverlays.append(objectOverlay)
        }

        // Hands off drawing to the OverlayView
        self.draw(objectOverlays: objectOverlays)

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
//            else if caloriesOfFood.keys.contains((food?.type)!) {
//                os_log("Food is set. Continue to calculate calories", log: OSLog.default, type: .debug)
//                return true
//            } else {
//                let notInDBAlert = UIAlertController(title: "Alert", message: "The information has not been set for this type!", preferredStyle: .alert)
//                notInDBAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
//                    NSLog("The \"OK\" alert occured.")
//                }))
//                self.present(notInDBAlert, animated: true, completion: nil)
//                return false
//            }
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
    
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
