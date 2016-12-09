//
//  ViewController.swift
//  TYDirectionSwift
//
//  Created by Thabresh on 9/6/16.
//  Copyright © 2016 VividInfotech. All rights reserved.
//


import UIKit
import MapKit
import GoogleMaps
import GooglePlaces
import SWRevealViewController
import SwiftyJSON
import SVProgressHUD
import AVFoundation
import KDEAudioPlayer

import SOMotionDetector

class GetDirectionVC: UIViewController,UITextFieldDelegate,UISearchBarDelegate, LocateOnTheMap, GMSMapViewDelegate {
    
    // MARK: -
    // MARK: Vars
    
    var searchResultController:SearchResultsController!
    var resultsArray = [String]()
    var fromClicked = Bool()
    var mapManager = DirectionManager()
    var tableData = NSDictionary()
    var directionDetail = NSArray()
    var polyline: MKPolyline = MKPolyline()
    let markerNextTurn = GMSMarker()
    
    var isRouteStarted = false
    var nextTurnLocation:CLLocation?
    var instructions:String = ""
    var DistETAData = NSDictionary()
    
    var bizForRoute: Business?
    var routeTimer:NSTimer?
    var wetherTimer:NSTimer?
    var lasETASync:NSDate = NSDate()
    
    var lastSpeedSync:NSDate = NSDate()
    
    @IBOutlet var vNavHeader: UIView!
    @IBOutlet var btnMenu: UIButton?
    //@IBOutlet weak var drawMap: MKMapView!
    @IBOutlet weak var googleMapsView : GMSMapView!
    @IBOutlet weak var txtTo: UITextField!
    @IBOutlet weak var txtFrom: UITextField!
    @IBOutlet weak var lblSpeed: UILabel!
    @IBOutlet weak var btnGetDirection: UIButton!
    @IBOutlet weak var btnStartRoute: UIButton!
    @IBOutlet weak var btnRefresh: UIButton!
    
    @IBOutlet weak var Const_P_headerviewHeight: NSLayoutConstraint!
    //@IBOutlet weak var Const_P_lblToLeading: NSLayoutConstraint!
    //@IBOutlet weak var Const_P_btnCLocTrailing: NSLayoutConstraint!
    @IBOutlet weak var Const_P_LocationInputTopMargin: NSLayoutConstraint!
    
    @IBOutlet weak var Const_P_SRouteLead: NSLayoutConstraint!
    @IBOutlet weak var Const_P_SRouteBottom: NSLayoutConstraint!
    
    // MARK: -
    // MARK: Orientation
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        coordinator.animateAlongsideTransition({ (UIViewControllerTransitionCoordinatorContext) -> Void in
            
            let orient = UIApplication.sharedApplication().statusBarOrientation
            
            switch orient {
            case .Portrait:
                print("Portrait")
                self.lblSpeed.layoutIfNeeded()
                self.ApplyportraitConstraint()
                break
            default:
                print("LandScape")
                self.lblSpeed.layoutIfNeeded()
                self.applyLandScapeConstraint()
                break
            }
        }, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
            print("rotation completed")
        })
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    }
    
    func ApplyportraitConstraint() {
        Const_P_headerviewHeight.constant = 64
        Const_P_LocationInputTopMargin.constant = 0
        Const_P_SRouteLead.constant = 8
        Const_P_SRouteBottom.constant = 8
        
        //self.view.addConstraint(self.portrateConstraint3)
        //self.view.removeConstraint(self.landScapeConstraint)
    }
    
    func applyLandScapeConstraint() {
        Const_P_headerviewHeight.constant = 44
        Const_P_LocationInputTopMargin.constant = (isRouteStarted) ? -46 : 0
        Const_P_SRouteLead.constant = 0
        Const_P_SRouteBottom.constant = (-1 * (self.btnStartRoute.frame.height))
        
        //self.view.removeConstraint(self.portrateConstraint3)
        //self.view.addConstraint(self.landScapeConstraint)
        
    }
    
    // MARK: -
    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchResultController = SearchResultsController()
        searchResultController.delegate = self
        
        googleMapsView.delegate = self
        
        
        btnGetDirection.enabled = false
        btnGetDirection.backgroundColor = UIColor.darkGrayColor()
        btnStartRoute.enabled = false
        btnStartRoute.backgroundColor = UIColor.darkGrayColor()
        self.btnStartRoute.tag == 1
        
        txtFrom.text = "Current Location"
        //txtFrom.text = "Santo Domingo"
        self.lblSpeed.text = ""
        
        
        let btnCLocation = UIButton(frame: CGRectMake(0, 0, 22, 22))
        btnCLocation.setBackgroundImage(UIImage(named: "ic_current_location"), forState: .Normal)
//        btnCLocation.per
        btnCLocation.addTarget(self, action: #selector(GetDirectionVC.actinoSetFromCurrentLocation(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        
        let paddingRight = UIView(frame: CGRectMake(0, 0, 24, 22))
        paddingRight.backgroundColor = UIColor.clearColor()
        paddingRight.addSubview(btnCLocation)
        btnCLocation.center = paddingRight.center
        txtFrom.rightView = paddingRight
        txtFrom.rightViewMode = UITextFieldViewMode .Always
        
        //txtFrom.setRightMargin()
        //self.startFiveTapGesture()
        vNavHeader.addFiveTapGesture(self)
        
        if bizForRoute != nil {
            self.btnMenu?.setTitle("Back", forState: .Normal)
            self.btnMenu?.addTarget(self, action: #selector(GetDirectionVC.actionGoToBack(_:)), forControlEvents: .TouchUpInside)
            self.txtTo.text = "\(bizForRoute?.coordinate?.latitude ?? 0),\(bizForRoute?.coordinate?.longitude ?? 0)"
            self.ClickToGo(nil)
        } else {
            // Init menu button action for menu
            if let revealVC = self.revealViewController() {
                self.btnMenu?.addTarget(revealVC, action: #selector(revealVC.revealToggle(_:)), forControlEvents: .TouchUpInside)
                //self.view.addGestureRecognizer(revealVC.panGestureRecognizer());
                //self.navigationController?.navigationBar.addGestureRecognizer(revealVC.panGestureRecognizer())
            }
        }
        
//        player = AVPlayer(URL: NSURL(string: "\(BaseUrlSounds)Directional/to-the-left2.wav")!)
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GetDirectionVC.playerDidFinishPlaying(_:)),
//                                                         name: AVPlayerItemDidPlayToEndTimeNotification, object: player!.currentItem)
        
        
        let camera = GMSCameraPosition.cameraWithLatitude(53.9,longitude: 27.5667, zoom: 6)
        self.googleMapsView.animateToCameraPosition(camera)
        
        if LocationManager.sharedInstance.hasLastKnownLocation == false {
            LocationManager.sharedInstance.onFirstLocationUpdateWithCompletionHandler { (latitude, longitude, status, verboseMessage, error) in
                print(latitude,longitude,status)
                CLocation = CLLocation(latitude: latitude, longitude: longitude)
                self.googleMapsView.camera = GMSCameraPosition(target: CLocation!.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
            }
        } else {
            self.googleMapsView.camera = GMSCameraPosition(target: CLocation!.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
        }
        
        LocationManager.sharedInstance.DidUpdateHeadingHandler = {(newHeading: CLHeading) -> Void in
            print(newHeading)
        }
        
        //self.googleMapsView.delegate = self
        self.googleMapsView.myLocationEnabled = true
        self.googleMapsView.settings.myLocationButton = true
        
        
//        AudioItems?.append(AudioItem(soundURLs: [AudioQuality.Medium : NSURL(string: "\(BaseUrlSounds)Directional/to-the-left2.wav")!])!)
//        AudioItems?.append(AudioItem(soundURLs: [AudioQuality.Medium : NSURL(string: "\(BaseUrlSounds)Directional/to-the-right.wav")!])!)
//        AudioItems?.append(AudioItem(soundURLs: [AudioQuality.Medium : NSURL(string: "\(BaseUrlSounds)Directional/to-the-left2.wav")!])!)
//        AudioItems?.append(AudioItem(soundURLs: [AudioQuality.Medium : NSURL(string: "\(BaseUrlSounds)Directional/to-the-right.wav")!])!)
//        AudioItems?.append(AudioItem(soundURLs: [AudioQuality.Medium : NSURL(string: "\(BaseUrlSounds)Directional/to-the-left2.wav")!])!)
//        player.mode = .NoRepeat
//        player.playItems(AudioItems!, startAtIndex: 0)
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        UIApplication.sharedApplication().idleTimerDisabled = false
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        print("Video Finished")
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        textField .resignFirstResponder()
        if textField.tag == 0 {
            fromClicked = true
        } else {
            fromClicked = false
        }
        let searchController = UISearchController(searchResultsController: searchResultController)
        searchController.searchBar.delegate = self
        self.presentViewController(searchController, animated: true, completion: nil)
    }
    
    func locateWithLongitude(lon: Double, andLatitude lat: Double, andTitle title: String) {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            if self.fromClicked {
                self.txtFrom.text = title
                self.navigationItem.prompt = String(format: "From :%f,%f",lat,lon)
            } else {
                self.txtTo.text = title
                self.navigationItem.title = String(format: "TO :%f,%f",lat,lon)
            }
        }
    }
    
    func searchBar(searchBar: UISearchBar,
                   textDidChange searchText: String){
        let placesClient = GMSPlacesClient()
        placesClient.autocompleteQuery(searchText, bounds: nil, filter: nil) { (results, error:NSError?) -> Void in
            self.resultsArray.removeAll()
            if results == nil {
                return
            }
            for result in results!{
                if let result = result as? GMSAutocompletePrediction {
                    self.resultsArray.append(result.attributedFullText.string)
                }
            }
            self.searchResultController.reloadDataWithArray(self.resultsArray)
        }
    }
    
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.init(colorLiteralRed: 0/255.0, green: 122.0/255.0, blue: 255.0/255.0, alpha: 1.0)
            polylineRenderer.lineWidth = 3
            return polylineRenderer
        }
        return MKOverlayRenderer()
    }
    
    func removeAllPlacemarkFromMap(shouldRemoveUserLocation shouldRemoveUserLocation:Bool) {
        //        if let mapView = self.googleMapsView {
        //            for annotation in mapView.annotations{
        //                if shouldRemoveUserLocation {
        //                    if annotation as? MKUserLocation !=  mapView.userLocation {
        //                        mapView.removeAnnotation(annotation as MKAnnotation)
        //                    }
        //                }
        //                let overlays = mapView.overlays
        //                mapView.removeOverlays(overlays)
        //            }
        //        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - GMSMapViewDelegate
    
    func mapView(mapView: GMSMapView, idleAtCameraPosition position: GMSCameraPosition) {
        print(position.target)
//        let camera = googleMapsView.camera
//        let camera1 = GMSCameraPosition(target: camera.target, zoom: camera.zoom, bearing: camera.bearing + 10, viewingAngle: camera.viewingAngle)
//        //var camera = googleMapsView.camera
//        //camera.bearing = camera.bearing + 10
//        googleMapsView.animateToCameraPosition(camera1)
        
    }
    
    func mapView(mapView: GMSMapView, willMove gesture: Bool) {
        if (gesture) {
            mapView.selectedMarker = nil
            //self.btnDirection.hidden = true
        }
    }
    
    
    // MARK: - IBAction
    
    @IBAction func actinoSetFromCurrentLocation(sender: AnyObject) {
        if let curLocation = CLocation
            where curLocation.coordinate.latitude != 0
                && curLocation.coordinate.longitude != 0
        {
            if isRouteStarted {
                self.stopObservingRoute()
            }
            txtFrom.text = "Current Location"
        } else {
            SVProgressHUD.showInfoWithStatus("Oops, We are unable to find your location.. \n you can try to search")
        }
    }
    
    @IBAction func actionGoToBack(sender: AnyObject) {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    @IBAction func clickToGetDirection(sender: AnyObject) {
        if self.tableData.count > 0 {
            self .performSegueWithIdentifier("direction", sender: self)
            //self.DirectionDetailTableViewCell.hidden = false;
        }
    }
    
    @IBAction func actionStartRoute(sender: AnyObject)
    {
        if self.btnStartRoute.enabled
            && self.btnStartRoute.tag == 1
        {
            self.btnRefresh.hidden = true
            self.btnStartRoute.setTitle("Stop Route", forState: .Normal)
            self.btnStartRoute.backgroundColor = clrGreen
            self.btnStartRoute.tag = 2;
            
            let camera = GMSCameraPosition.cameraWithLatitude(LocationManager.sharedInstance.latitude,longitude: LocationManager.sharedInstance.longitude, zoom: 1)
            self.googleMapsView.animateToCameraPosition(camera)
            
            print("Start monitoring route")
            startObservingRoute()
        } else if self.btnStartRoute.enabled
            && self.btnStartRoute.tag == 2
        {
            self.btnRefresh.hidden = false
            self.btnStartRoute.setTitle("Start Route", forState: .Normal)
            self.btnStartRoute.backgroundColor = clrRed
            self.btnStartRoute.tag = 1;
            
            print("stop monitoring route")
            stopObservingRoute()
        }
    }
    
    // MARK: -
    // MARK: Custom Method
    
    
    //Calculates ETA and Distance on every 10 seconds while user is on Route or Direction
    func getDistanceETA()
    {
        
        if lasETASync.timeIntervalSinceNow > -10 {
            //Sync at every 10 seconds of minimum interval
            return
        }
        
        lasETASync = NSDate()
        
        if CLocation?.coordinate.latitude == 0
            && CLocation?.coordinate.longitude == 0
        {
            CLocation = LocationManager.sharedInstance.CLocation
        }
        
        let FromLocString = "\(CLocation!.coordinate.latitude),\(CLocation!.coordinate.longitude)"
        let ToLocString = "\(self.nextTurnLocation!.coordinate.latitude),\(self.nextTurnLocation!.coordinate.longitude)"
        
        mapManager.directionsUsingGoogle(from: FromLocString, to: ToLocString) { (route,encodedPolyLine ,directionInformation, boundingRegion, error) -> () in
            
            if(error != nil)
            {
                print(error)
            }
            else
            {
                print("directionInformation ",directionInformation)
                
                dispatch_async(dispatch_get_main_queue())
                {
                    //instructions
                    //
                    
                    self.lblSpeed.setHTMLFromString(self.instructions.stringByReplacingOccurrencesOfString("\n", withString: " ") + " (" + ((directionInformation?.objectForKey("duration") as? NSString ?? "") as String) + " - " + ((directionInformation?.objectForKey("distance") as? NSString ?? "") as String) + ")")
                    
//                    let start_location = directionInformation?.objectForKey("start_location") as! NSDictionary
//                    let originLat = start_location.objectForKey("lat")?.doubleValue
//                    let originLng = start_location.objectForKey("lng")?.doubleValue
//                    
//                    let end_location = directionInformation?.objectForKey("end_location") as! NSDictionary
//                    let destLat = end_location.objectForKey("lat")?.doubleValue
//                    let destLng = end_location.objectForKey("lng")?.doubleValue
//                    
//                    let coordOrigin = CLLocationCoordinate2D(latitude: originLat!, longitude: originLng!)
//                    let coordDesitination = CLLocationCoordinate2D(latitude: destLat!, longitude: destLng!)
//                    
//                    let markerOrigin = GMSMarker()
//                    markerOrigin.groundAnchor = CGPoint(x: 0.5, y: 1)
//                    markerOrigin.appearAnimation = kGMSMarkerAnimationPop
//                    markerOrigin.icon = UIImage(named: "default_marker.png")
//                    markerOrigin.title = directionInformation?.objectForKey("start_address") as! NSString as String
//                    markerOrigin.snippet = directionInformation?.objectForKey("duration") as! NSString as String
//                    markerOrigin.position = coordOrigin
                    
                }
            }
        }
    }
    
    // Plays Genereal sounds on each time
    func onEveryTwentyMinutesOfRoute()
    {
        //recordTimer?.invalidate()
        print("onEveryTwentyMinutesOfRoute \(routeTimer)")
        
        if let mp3Url = NSURL(string: "\(BaseUrlSounds)General-Categories/home-and-office-stores.wav") {
            //            mp3Urls.append(mp3Url)
            if let AudioIdem = AudioItem(soundURLs: [AudioQuality.Medium : mp3Url]) {
                player.mode = .NoRepeat
                player.playItem(AudioIdem)
            }
        }
    }
    
    // Plays Wether sounds
    func onPlayWeatherAudio()
    {
        //wetherTimer?.invalidate()
        print("onPlayWeatherAudio \(wetherTimer) \(weather) \n\n")
        
        
        print("humidity \(weather?.humidity)")
        print("pressure \(weather?.pressure)")
        print("cloudCover \(weather?.cloudCover)")
        print("windSpeed \(weather?.windSpeed)")
        
        print("windDirection \(weather?.windDirection)")
        print("rainfallInLast3Hours \(weather?.rainfallInLast3Hours)")
        
        if weather == nil {
            return
        }
        
        // !! Here i comapres rainfallInLast3Hours to check sunny or rainy season but we also includes cloudCover, humidity as you would like !!
        // Rainy season check
        if let rainfallInLast3Hours = weather?.rainfallInLast3Hours
            where rainfallInLast3Hours >= 0.5
        {
            //Rainy day
            if let mp3Url = NSURL(string: "\(BaseUrlSounds)General-Categories/home-services.wav") {
                //            mp3Urls.append(mp3Url)
                if let AudioIdem = AudioItem(soundURLs: [AudioQuality.Medium : mp3Url]) {
                    player.mode = .NoRepeat
                    player.playItem(AudioIdem)
                }
            }
        } else {
            //Sunny day
            if let mp3Url = NSURL(string: "\(BaseUrlSounds)General-Categories/home-services.wav") {
                //            mp3Urls.append(mp3Url)
                if let AudioIdem = AudioItem(soundURLs: [AudioQuality.Medium : mp3Url]) {
                    player.mode = .NoRepeat
                    player.playItem(AudioIdem)
                }
            }
        }
    }
    
    func startObservingRoute()
    {
        isRouteStarted = true
        
        UIApplication.sharedApplication().idleTimerDisabled = true
        
        weatherGetter.getWeatherByCoordinates(latitude: CLocation?.coordinate.latitude ?? 0 ,
                                              longitude: CLocation?.coordinate.longitude ?? 0)
        
        lastSpeedSync = NSDate()
        
        // Plays Wether sounds on every 20 minutes
        wetherTimer = NSTimer.scheduledTimerWithTimeInterval(19*60, target: self, selector: #selector(GetDirectionVC.onPlayWeatherAudio), userInfo: nil, repeats: true)
        
        //Start 20 Minute timer (Low 5, Medium 10, High 20)
        let TimeInteval_Priority:Double = ((Myfilters.SettingSub == SubSetting[0]) ? 5 : (Myfilters.SettingSub == SubSetting[1]) ? 10 : 20)
        routeTimer = NSTimer.scheduledTimerWithTimeInterval(TimeInteval_Priority * 60, target: self, selector: #selector(GetDirectionVC.onEveryTwentyMinutesOfRoute), userInfo: nil, repeats: true)
        
        self.directionDetail = self.tableData.objectForKey("steps") as! NSArray
        print("",self.directionDetail)
        var routePos = 0
        let dictTable:NSDictionary = self.directionDetail[0] as! NSDictionary
        print(" startObservingRoute \n\n\n startObservingRoute",dictTable)
        
        instructions = (dictTable.objectForKey("html_instructions") as? NSString ?? "") as String
        //+ " (" + ((dictTable.objectForKey("duration") as? NSString ?? "") as String) + " - " + ((dictTable.objectForKey("distance") as? NSString ?? "") as String) + ")"
        self.lblSpeed.setHTMLFromString(((dictTable.objectForKey("html_instructions") as? NSString ?? "") as String + " (" + ((dictTable.objectForKey("duration") as? NSString ?? "") as String) + " - " + ((dictTable.objectForKey("distance") as? NSString ?? "") as String) + ")").stringByReplacingOccurrencesOfString("\n", withString: " "))
        
        //cell.directionDetail.text =  dictTable["instructions"] as? String
        //let distance = dictTable["distance"] as! NSString
        let nextTurn = dictTable["end_location"] as! NSDictionary
        nextTurnLocation = CLLocation(latitude: nextTurn["lat"] as? CLLocationDegrees ?? 0, longitude: nextTurn["lng"] as? CLLocationDegrees ?? 0)
        
        markerNextTurn.groundAnchor = CGPoint(x: 0.5, y: 1)
        markerNextTurn.appearAnimation = kGMSMarkerAnimationPop
        markerNextTurn.icon = UIImage(named: "pin_blue")
        markerNextTurn.title = dictTable.objectForKey("instructions") as! NSString as String
        markerNextTurn.position = nextTurnLocation!.coordinate
        markerNextTurn.map = self.googleMapsView
        
        
        let camera = GMSCameraPosition.cameraWithLatitude(LocationManager.sharedInstance.latitude,longitude: LocationManager.sharedInstance.longitude, zoom: 19)
        self.googleMapsView.camera = camera  //animateToCameraPosition(camera)
        
        LocationManager.sharedInstance.startUpdatingLocationWithCompletionHandler { (latitude, longitude, status, verboseMessage, error) in
        
            //27-2-2018
            print("Speed : ",CLocation?.speed)
            
            //if let speed = CLocation?.speed {
            //    self.lblSpeed.text = "Speed \(speed)  KMPH \(speed * 3.6)"
            //}
            print("\n")
            
            CLocation = CLLocation(latitude: latitude, longitude: longitude)
            print("Updating Location To Detect Turns : ",LocationManager.sharedInstance.latitude," - ",LocationManager.sharedInstance.longitude)
            
            //let FromCLocation = CLLocation(latitude: self.googleMapsView.camera.target.latitude , longitude: self.googleMapsView.camera.target.longitude)
            let camera = self.googleMapsView.camera
            let camera1 = GMSCameraPosition(target: CLocation!.coordinate, zoom: camera.zoom, bearing: getBearingBetweenTwoPoints(CLocation!, point2: self.nextTurnLocation!), viewingAngle: camera.viewingAngle)
            //var camera = googleMapsView.camera
            //camera.bearing = camera.bearing + 10
            self.googleMapsView.animateToCameraPosition(camera1)
            
            
            print("Distance -",routePos,", ",self.directionDetail.count,"- : ",self.nextTurnLocation!.distanceFromLocation(LocationManager.sharedInstance.CLocation!))
            
            //Check use is in range of 50 Meters from next turn location
            if self.nextTurnLocation!.distanceFromLocation(LocationManager.sharedInstance.CLocation!) < 10
                && self.directionDetail.count > routePos
            {
                routePos += 1
                let dictTable:NSDictionary = self.directionDetail[routePos] as! NSDictionary
                print("\n\n\n",dictTable)
                let nextTurn = dictTable["end_location"] as! NSDictionary
                self.nextTurnLocation! = CLLocation(latitude: nextTurn["lat"] as? CLLocationDegrees ?? 0, longitude: nextTurn["lng"] as? CLLocationDegrees ?? 0)
                self.markerNextTurn.position = self.nextTurnLocation!.coordinate
                self.markerNextTurn.title = dictTable.objectForKey("instructions") as! NSString as String
                
                //html_instructions
                self.instructions = (dictTable.objectForKey("html_instructions") as? NSString ?? "") as String //+ " (" + ((dictTable.objectForKey("duration") as? NSString ?? "") as String) + " - " + ((dictTable.objectForKey("distance") as? NSString ?? "") as String) + ")"
                self.lblSpeed.setHTMLFromString(((dictTable.objectForKey("html_instructions") as? NSString ?? "") as String + " (" + ((dictTable.objectForKey("duration") as? NSString ?? "") as String) + " - " + ((dictTable.objectForKey("distance") as? NSString ?? "") as String) + ")").stringByReplacingOccurrencesOfString("\n", withString: " "))
                
                let camera = GMSCameraPosition.cameraWithLatitude(LocationManager.sharedInstance.latitude,longitude: LocationManager.sharedInstance.longitude, zoom: self.googleMapsView.camera.zoom)
                self.googleMapsView.animateToCameraPosition(camera)
                
                //Turn right - /Directional/to-the-right.wav
                //Turn left - /Directional/to-the-left.wav
                //Keep right to - /Directional/to-the-right.wav
                //Keep left to - /Directional/to-the-left.wav
                
                // To play sound on base of instruction
                self.playSoundForInstruction(dictTable.objectForKey("instructions") as? NSString as? String)
            }
            else if self.nextTurnLocation!.distanceFromLocation(LocationManager.sharedInstance.CLocation!) < 10
                && self.directionDetail.count == routePos+1
            {
                //Finish tracking
                //Reach at destination
                
                self.stopObservingRoute()
            }
            
            if self.isRouteStarted {
                self.getDistanceETA()
            }
            
            //Check Speed Test for 25Miles/Second
            if let speed = CLocation?.speed where speed < 25 {
                print("lastSpeedSync Duration : ",self.lastSpeedSync.timeIntervalSinceNow)
                if self.lastSpeedSync.timeIntervalSinceNow <= -120 {
                    self.lastSpeedSync = NSDate()
                    
                    //Play Sound after 2 minutes if speed is less than 25 mile/S
                    //statement12.wav - i know you are texting
                    if let mp3Url = NSURL(string: "\(BaseUrlSounds)TrafficMonitor-LITE/statement12.wav") {
                        //mp3Urls.append(mp3Url)
                        if let AudioIdem = AudioItem(soundURLs: [AudioQuality.Medium : mp3Url]) {
                            player.mode = .NoRepeat
                            player.playItem(AudioIdem)
                        }
                    }
                }
            } else {
                self.lastSpeedSync = NSDate()
                print("you are going fast as speed of : ",CLocation?.speed ?? 0)
            }
        }
    }
    
    func stopObservingRoute()
    {
        isRouteStarted = false
        
        UIApplication.sharedApplication().idleTimerDisabled = false
        
        self.btnRefresh.hidden = false
        LocationManager.sharedInstance.startUpdatingLocationWithCompletionHandler(nil)
        markerNextTurn.map = nil
        
        //Stop 20 Minute timer
        routeTimer?.invalidate()
    }
    
    func playSoundForInstruction(instruction:String?)
    {
        AudioItems?.removeAll()
        player.stop()
        
        guard let inst = instruction else {
            print("Instruction not found")
            return
        }
        
        print("Playing Sound for instruction : \(inst)")
        //self.AddAudioToQueue(ofUrl: "http://www.notchrisrock.com/gps/api/sounds/Route/route.wav")
        
        print(">>> >> > > Select Sound based on SettingMain & SettingSub : \(Myfilters.SettingMain)  \(Myfilters.SettingSub)")
        
        AudioItems = []
        
        // Start Route
//        if inst.containsIgnoringCase("StartRoute") {
//            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/lets-go.wav")
//        }
        
//        "And" = "&"
//        "A" = "a"
//        "B" = "b"
//        "C" = "c"
//        "D" = "d"
//        "E" = "e"
//        "F" = "f"
//        "G" = "g"
//        "H" = "h"
//        "I" = "i"
//        "J" = "j"
//        "K" = "k"
//        "L" = "l"
//        "M" = "m"
//        "N" = "n"
//        "O" = "o"
//        "P" = "p"
//        "Q" = "q"
//        "R" = "r"
//        "S" = "s"
//        "T" = "t"
//        "U" = "u"
//        "V" = "v"
//        "W" = "w"
//        "X" = "x"
//        "Y" = "y"
//        "Z" = "z"
//        " " = "-"
        
        // General Statements
        if inst.containsIgnoringCase("Airport") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/airports.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("airport", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Amusement Park") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/amuzement-parks.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("airport", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("ATM") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/ATM.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("ATM", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("ATMs") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/ATMs.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("airport", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Bank") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/banks.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Barbershop") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/barbershops.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("barbershops", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Bars") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/bars.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("bars", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Beauty") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/beauty-shops.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("beauty-shops", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Beer") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/beer.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("beer", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Bus Stops") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/bus-stops.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("bus-stops", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Car Rental") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/car-rental.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("car-rental", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Clothing Store") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/clothing-stores.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("clothing-stores", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Coffee Shops") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/coffeeshops.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("coffeeshops", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Convenience Stores") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/conv-stores.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("conv-stores", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Department Stores") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/department-stores.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("department-stores", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Desserts") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/desserts.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("desserts", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Drugstores") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/drugstores.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("drugstores", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Dry Cleaners") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/dry-cleaners.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("dry-cleaners", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Fast Food") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/fast-food.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("fast-food", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Fitness Centers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/fitness-centers.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("fitness-centers", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Gas Stations") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/gas-stations.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("gas-stations", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Grocery Stores") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/groceries-stores.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("groceries-stores", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Home & Office Stores") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/home-and-office-stores.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("home-and-office-stores", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Home Services") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/home-services.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("home-services", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Hospitals") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/hospitals.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("hospitals", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Hotels") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/hotels.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("hotels", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Landmarks") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/landmarks.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("landmarks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Laundry") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/laundry.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("laundry", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Movies") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/movies.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Museums") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/museums.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Nightclubs") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/nightclubs.wav")
            //            self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Parking") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/parking.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Parks") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/parks.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Pet Stores") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/pet-stores.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Pharmacies") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/pharmacies.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Post Offices") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/post-offices.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Restaurants") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/restaurants.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Sporting Goods") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/sporting-goods.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Tea & Juice") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/tea-and-juice.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Transit Stations") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/transit-stations.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        if inst.containsIgnoringCase("Wine") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)General-Categories/wine.wav")
            //self.AddAudioToQueue(ofUrl: NSBundle.mainBundle().URLForResource("banks", withExtension: "wav")?.absoluteString)
        }
        
        // Directional Statements
        if inst.containsIgnoringCase("Turn right") {
            //Audio: Turn Right
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/turn-right.wav")
        } else if inst.containsIgnoringCase("Turn left") {
            //Audio: Turn Left
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/turn-left.wav")
        } else if inst.containsIgnoringCase("To right") || inst.containsIgnoringCase("To the right") || inst.containsIgnoringCase("Turn right to") {
            //Audio: Turn Right
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/to-the-right.wav")
        } else if inst.containsIgnoringCase("To left") || inst.containsIgnoringCase("To the left") || inst.containsIgnoringCase("Turn left to") {
            //Audio: Turn Left
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/to-the-left.wav")
        } else if inst.containsIgnoringCase("Turn right onto") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/to-the-right2.wav")
        } else if inst.containsIgnoringCase("Turn left onto") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Directional/to-the-left2.wav")
        }
        
        // Highway
        if inst.containsIgnoringCase("highway") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Highway/highway.wav")
        }
        
        // Food store name
        if inst.containsIgnoringCase("5 Guys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/5-guys.wav")
        }
        else if inst.containsIgnoringCase("7/11") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/7-11.wav")
        }
        else if inst.containsIgnoringCase("A&W") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/a&w.wav")
        }
        else if inst.containsIgnoringCase("Applebees") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/applebees.wav")
        }
        else if inst.containsIgnoringCase("Arbys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/arbys.wav")
        }
        else if inst.containsIgnoringCase("Backyard Burgers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/backyardburgers.wav")
        }
        else if inst.containsIgnoringCase("Bakers Dozen Donuts") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/bakers-dozen-donuts.wav")
        }
        else if inst.containsIgnoringCase("Bar-B-Cutie") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/bar-b-cutie.wav")
        }
        else if inst.containsIgnoringCase("Bar Burrito") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/barburrito.wav")
        }
        else if inst.containsIgnoringCase("Baskin Robbins") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/baskin-robbins.wav")
        }
        else if inst.containsIgnoringCase("Beaver Tails") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/beavertails.wav")
        }
        else if inst.containsIgnoringCase("Ben & Florentine") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/ben-and-florentine.wav")
        }
        else if inst.containsIgnoringCase("Ben & Jerrys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/ben-and-jerrys.wav")
        }
        else if inst.containsIgnoringCase("Benjys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/benjys.wav")
        }
        else if inst.containsIgnoringCase("Big Boy") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/big-boy.wav")
        }
        else if inst.containsIgnoringCase("BJs") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/bjs.wav")
        }
        else if inst.containsIgnoringCase("Blimpie") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/blimpie3.wav")
        }
        else if inst.containsIgnoringCase("Bob Evans") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/bob-evans.wav")
        }
        else if inst.containsIgnoringCase("Bojangles") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/bojangles.wav")
        }
        else if inst.containsIgnoringCase("Bonefish Grill") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/bonefish-grill.wav")
        }
        else if inst.containsIgnoringCase("Booster-Juice") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/booster-juice.wav")
        }
        else if inst.containsIgnoringCase("Boston Market") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/boston-market.wav")
        }
        else if inst.containsIgnoringCase("Boston Pizza") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/boston-pizza.wav")
        }
        else if inst.containsIgnoringCase("Burger Baron") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/burger-baron.wav")
        }
        else if inst.containsIgnoringCase("Burger King") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/burger-king.wav")
        }
        else if inst.containsIgnoringCase("BW3") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/BW3.wav")
        }
        else if inst.containsIgnoringCase("C Lovers Fish-N-Chips") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/c-lovers-fish-n-chips.wav")
        }
        else if inst.containsIgnoringCase("Captain Ds Seafood") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/Capt-Ds-Seafood.wav")
        }
        else if inst.containsIgnoringCase("Captain Submarine") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/captain-submarine.wav")
        }
        else if inst.containsIgnoringCase("Captains Sub") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/capts-sub.wav")
        }
        else if inst.containsIgnoringCase("Carls Jr") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/carls-jr.wav")
        }
        else if inst.containsIgnoringCase("Carrabbas") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/carrabbas.wav")
        }
        else if inst.containsIgnoringCase("Checkers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/checkers.wav")
        }
        else if inst.containsIgnoringCase("Cheddars") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cheddars.wav")
        }
        else if inst.containsIgnoringCase("Cheesecake Factory") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cheesecake-factory.wav")
        }
        else if inst.containsIgnoringCase("Chez Ashton") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chez-aston.wav")
        }
        else if inst.containsIgnoringCase("Chic-Fil-A") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chic-fil-a.wav")
        }
        else if inst.containsIgnoringCase("Chicken Cottage") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chicken-cottage.wav")
        }
        else if inst.containsIgnoringCase("Chicken Delight") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chicken-delight.wav")
        }
        else if inst.containsIgnoringCase("Chilis") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chilis.wav")
        }
        else if inst.containsIgnoringCase("Chipotle") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chipotle.wav")
        }
        else if inst.containsIgnoringCase("Chuck-E-Cheese") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/chuck-e-cheese.wav")
        }
        else if inst.containsIgnoringCase("Churchs Chicken") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/churchs-chicken.wav")
        }
        else if inst.containsIgnoringCase("Cicis Pizza") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cicis-pizza.wav")
        }
        else if inst.containsIgnoringCase("Cinnabun") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cinnabun.wav")
        }
        else if inst.containsIgnoringCase("Circle K") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/circle-k.wav")
        }
        else if inst.containsIgnoringCase("Coffee Time") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/coffeetime.wav")
        }
        else if inst.containsIgnoringCase("Cora") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cora.wav")
        }
        else if inst.containsIgnoringCase("Country Style") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/countrystyle.wav")
        }
        else if inst.containsIgnoringCase("Cows Ice Cream") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cows-ice-cream.wav")
        }
        else if inst.containsIgnoringCase("CPK") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cpk.wav")
        }
        else if inst.containsIgnoringCase("Cracker Barrel") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/cracker-barrel.wav")
        }
        else if inst.containsIgnoringCase("Culvers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/culvers.wav")
        }
        else if inst.containsIgnoringCase("Dairy Queen") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dairy-queen.wav")
        }
        else if inst.containsIgnoringCase("Del Taco") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/del-taco")
        }
        else if inst.containsIgnoringCase("Dennys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dennys.wav")
        }
        else if inst.containsIgnoringCase("Dic Anns Hamburgers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dic-ann-hamburgers.wav")
        }
        else if inst.containsIgnoringCase("Dixie Chicken") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dixie-chicken.wav")
        }
        else if inst.containsIgnoringCase("Dixie Lee Fried Chicken") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dixie-lee-fried-chicken.wav")
        }
        else if inst.containsIgnoringCase("Dominos") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dominos.wav")
        }
        else if inst.containsIgnoringCase("Donut Diner") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/donut-diner.wav")
        }
        else if inst.containsIgnoringCase("Dunkin Donuts") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/dunkin-donuts.wav")
        }
        else if inst.containsIgnoringCase("East Side Marios") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/east-side-marios.wav")
        }
        else if inst.containsIgnoringCase("Eat Restaurant") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/eat-restaurant.wav")
        }
        else if inst.containsIgnoringCase("Edo Japan") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/edo-japan.wav")
        }
        else if inst.containsIgnoringCase("Eds Easy Diner") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/applebees.wav")
        }
        else if inst.containsIgnoringCase("eds-easy-diner") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/applebees.wav")
        }
        else if inst.containsIgnoringCase("Einstein Brothers Bagels") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/einstein-bros-bagels.wav")
        }
        else if inst.containsIgnoringCase("Extreme Pita") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/extreme-pita.wav")
        }
        else if inst.containsIgnoringCase("Famous Daves") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/famous-daves.wav")
        }
        else if inst.containsIgnoringCase("Fast Eddies") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/fast-eddies.wav")
        }
        else if inst.containsIgnoringCase("Firehouse Subs") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/firehouse-subs.wav")
        }
        else if inst.containsIgnoringCase("Friendlys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/friendlys.wav")
        }
        else if inst.containsIgnoringCase("Fryers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/fryers.wav")
        }
        else if inst.containsIgnoringCase("Gojis") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/gojis.wav")
        }
        else if inst.containsIgnoringCase("Golden Corral") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/golden-corral.wav")
        }
        else if inst.containsIgnoringCase("Greco Pizza") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/greco-pizza.wav")
        }
        else if inst.containsIgnoringCase("Hardees") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/hardees.wav")
        }
        else if inst.containsIgnoringCase("Harveys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/harveys.wav")
        }
        else if inst.containsIgnoringCase("Heros Cert Burgers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/heros-cert-burgers.wav")
        }
        else if inst.containsIgnoringCase("Ho Lee Chow") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/ho-lee-chow.wav")
        }
        else if inst.containsIgnoringCase("Hooters") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/hooters.wav")
        }
        else if inst.containsIgnoringCase("Humptys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/humptys.wav")
        }
        else if inst.containsIgnoringCase("IHOP") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/ihop.wav")
        }
        else if inst.containsIgnoringCase("In-And-Out-Burger") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/in-and-out-burger.wav")
        }
        else if inst.containsIgnoringCase("Jack In The Box") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/jack-in-the-box.wav")
        }
        else if inst.containsIgnoringCase("Jamba Juice") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/jamba-juice.wav")
        }
        else if inst.containsIgnoringCase("Jasons Deli") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/jasons-deli.wav")
        }
        else if inst.containsIgnoringCase("Jimmy Johns") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/jimmy-johns.wav")
        }
        else if inst.containsIgnoringCase("Jimmy The Greek") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/jimmy-the-greek.wav")
        }
        else if inst.containsIgnoringCase("Jugo Juice") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/jugo-juice.wav")
        }
        else if inst.containsIgnoringCase("Kaspas") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/kaspas.wav")
        }
        else if inst.containsIgnoringCase("KFC") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/kfc.wav")
        }
        else if inst.containsIgnoringCase("Krispy Kreme Doughnuts") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/krispy-kreme-dougnuts.wav")
        }
        else if inst.containsIgnoringCase("Krystal") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/krystal.wav")
        }
        else if inst.containsIgnoringCase("Labelle Prov") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/labelle-prov.wav")
        }
        else if inst.containsIgnoringCase("Licks Homeburgers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/licks-homeburgers.wav")
        }
        else if inst.containsIgnoringCase("Little Caesars") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/little-caesars.wav")
        }
        else if inst.containsIgnoringCase("Little Chef") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/little-chef.wav")
        }
        else if inst.containsIgnoringCase("Logans Roadhouse") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/logans-roadhouse.wav")
        }
        else if inst.containsIgnoringCase("Long John Silvers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/long-john-silvers.wav")
        }
        else if inst.containsIgnoringCase("Longhorn Steakhouse") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/longhorn-steakhouse.wav")
        }
        else if inst.containsIgnoringCase("Macaroni") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/macaroni-grill.wav")
        }
        else if inst.containsIgnoringCase("Manchu Wok") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/manchu-wok.wav")
        }
        else if inst.containsIgnoringCase("Mary Browns") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/mary-browns.wav")
        }
        else if inst.containsIgnoringCase("McDonalds") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/mcdonalds.wav")
        }
        else if inst.containsIgnoringCase("Millies Cookies") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/millies-cookies.wav")
        }
        else if inst.containsIgnoringCase("Moes") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/moes.wav")
        }
        else if inst.containsIgnoringCase("Morleys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/morleys.wav")
        }
        else if inst.containsIgnoringCase("Mr. Greek") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/mr-greek.wav")
        }
        else if inst.containsIgnoringCase("Mr. Mikes") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/mr-mikes.wav")
        }
        else if inst.containsIgnoringCase("Mr. Sub") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/mr-sub.wav")
        }
        else if inst.containsIgnoringCase("NY Fries") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/ny-fries.wav")
        }
        else if inst.containsIgnoringCase("Ocharleys") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/Ocharleys.wav")
        }
        else if inst.containsIgnoringCase("Olive Garden") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/olive-garden.wav")
        }
        else if inst.containsIgnoringCase("On The Border") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/on-the-border.wav")
        }
        else if inst.containsIgnoringCase("Orange Julius") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/orange-julius.wav")
        }
        else if inst.containsIgnoringCase("Outback") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/outback.wav")
        }
        else if inst.containsIgnoringCase("Panago") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/panago.wav")
        }
        else if inst.containsIgnoringCase("Panda Express") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/panda-express.wav")
        }
        else if inst.containsIgnoringCase("Panera Bread") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/panera-bread.wav")
        }
        else if inst.containsIgnoringCase("Papa Johns") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Restaurants/papa-johns.wav")
        }
        
        
        
        // Interstate
        if inst.containsIgnoringCase("I-10") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i10.wav")
        }
        if inst.containsIgnoringCase("I-105") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i105.wav")
        }
        if inst.containsIgnoringCase("I-110") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i110.wav")
        }
        if inst.containsIgnoringCase("I-115") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i115.wav")
        }
        if inst.containsIgnoringCase("I-12") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i12.wav")
        }
        if inst.containsIgnoringCase("I-124") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i124.wav")
        }
        if inst.containsIgnoringCase("I-126") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i126.wav")
        }
        if inst.containsIgnoringCase("I-129") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i129.wav")
        }
        if inst.containsIgnoringCase("I-130") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i130.wav")
        }
        if inst.containsIgnoringCase("I-135") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i135.wav")
        }
        if inst.containsIgnoringCase("I-140") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i140.wav")
        }
        if inst.containsIgnoringCase("I-15") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i15.wav")
        }
        if inst.containsIgnoringCase("I-155") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i155.wav")
        }
        if inst.containsIgnoringCase("I-16") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i16.wav")
        }
        if inst.containsIgnoringCase("I-164") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i164.wav")
        }
        if inst.containsIgnoringCase("I-165") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i165.wav")
        }
        if inst.containsIgnoringCase("I-169") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i169.wav")
        }
        if inst.containsIgnoringCase("I-17") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i17.wav")
        }
        if inst.containsIgnoringCase("I-170") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i170.wav")
        }
        if inst.containsIgnoringCase("I-172") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i172.wav")
        }
        if inst.containsIgnoringCase("I-175") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i175.wav")
        }
        if inst.containsIgnoringCase("I-176") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i176.wav")
        }
        if inst.containsIgnoringCase("I-180") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i180.wav")
        }
        if inst.containsIgnoringCase("I-182") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i182.wav")
        }
        if inst.containsIgnoringCase("I-184") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i184.wav")
        }
        if inst.containsIgnoringCase("I-185") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i185.wav")
        }
        if inst.containsIgnoringCase("I-189") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i189.wav")
        }
        if inst.containsIgnoringCase("I-19") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i19.wav")
        }
        if inst.containsIgnoringCase("I-190") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i190.wav")
        }
        if inst.containsIgnoringCase("I-194") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i194.wav")
        }
        if inst.containsIgnoringCase("I-195") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i195.wav")
        }
        if inst.containsIgnoringCase("I-196") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i196.wav")
        }
        if inst.containsIgnoringCase("I-2") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i2.wav")
        }
        if inst.containsIgnoringCase("I-20") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i20.wav")
        }
        if inst.containsIgnoringCase("I-205") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i205.wav")
        }
        if inst.containsIgnoringCase("I-210") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i210.wav")
        }
        if inst.containsIgnoringCase("I-215") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i215.wav")
        }
        if inst.containsIgnoringCase("I-22") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i22.wav")
        }
        if inst.containsIgnoringCase("I-220") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i220.wav")
        }
        if inst.containsIgnoringCase("I-222") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i222.wav")
        }
        if inst.containsIgnoringCase("I-225") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i225.wav")
        }
        if inst.containsIgnoringCase("I-229") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i229.wav")
        }
        if inst.containsIgnoringCase("I-235") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i235.wav")
        }
        if inst.containsIgnoringCase("I-238") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i238.wav")
        }
        if inst.containsIgnoringCase("I-24") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i24.wav")
        }
        if inst.containsIgnoringCase("I-240") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i240.wav")
        }
        if inst.containsIgnoringCase("I-244") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i244.wav")
        }
        if inst.containsIgnoringCase("I-25") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i25.wav")
        }
        if inst.containsIgnoringCase("I-255") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i255.wav")
        }
        if inst.containsIgnoringCase("I-26") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i26.wav")
        }
        if inst.containsIgnoringCase("I-264") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i264.wav")
        }
        if inst.containsIgnoringCase("I-265") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i265.wav")
        }
        if inst.containsIgnoringCase("I-269") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i269.wav")
        }
        if inst.containsIgnoringCase("I-27") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i27.wav")
        }
        if inst.containsIgnoringCase("I-270") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i270.wav")
        }
        if inst.containsIgnoringCase("I-271") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i271.wav")
        }
        if inst.containsIgnoringCase("I-274") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i274.wav")
        }
        if inst.containsIgnoringCase("I-275") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i275.wav")
        }
        if inst.containsIgnoringCase("I-276") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i276.wav")
        }
        if inst.containsIgnoringCase("I-277") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i277.wav")
        }
        if inst.containsIgnoringCase("I-278") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i278.wav")
        }
        if inst.containsIgnoringCase("I-279") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i279.wav")
        }
        if inst.containsIgnoringCase("I-280") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i280.wav")
        }
        if inst.containsIgnoringCase("I-283") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i283.wav")
        }
        if inst.containsIgnoringCase("I-285") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i285.wav")
        }
        if inst.containsIgnoringCase("I-287") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i287.wav")
        }
        if inst.containsIgnoringCase("I-29") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i29.wav")
        }
        if inst.containsIgnoringCase("I-290") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i290.wav")
        }
        if inst.containsIgnoringCase("I-291") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i291.wav")
        }
        if inst.containsIgnoringCase("I-293") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i293.wav")
        }
        if inst.containsIgnoringCase("I-294") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i294.wav")
        }
        if inst.containsIgnoringCase("I-295") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i295.wav")
        }
        if inst.containsIgnoringCase("I-296") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i296.wav")
        }
        if inst.containsIgnoringCase("I-30") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Interstate/i30.wav")
        }
        
        // Food Types & Reviews
        if inst.containsIgnoringCase("African") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/african.wav")
        }
        if inst.containsIgnoringCase("American") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/american.wav")
        }
        if inst.containsIgnoringCase("Argentinian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/argentinian.wav")
        }
        if inst.containsIgnoringCase("Asian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/asian.wav")
        }
        if inst.containsIgnoringCase("Bagels") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/bagels.wav")
        }
        if inst.containsIgnoringCase("Bakery") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/bakeries.wav")
        }
        if inst.containsIgnoringCase("Barbeque") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/bbq")
        }
        if inst.containsIgnoringCase("Brazilian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/brazilian.wav")
        }
        if inst.containsIgnoringCase("Breakfast") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/breakfast.wav")
        }
        if inst.containsIgnoringCase("Cajun") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/cajun.wav")
        }
        if inst.containsIgnoringCase("Caribbean") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/carribean.wav")
        }
        if inst.containsIgnoringCase("Cheesecake") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/cheesecake.wav")
        }
        if inst.containsIgnoringCase("Chicken") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/chicken.wav")
        }
        if inst.containsIgnoringCase("Chinese") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/chinese.wav")
        }
        if inst.containsIgnoringCase("Coffee") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/coffee.wav")
        }
        if inst.containsIgnoringCase("Colombian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/colombian.wav")
        }
        if inst.containsIgnoringCase("Cuban") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/african.wav")
        }
        if inst.containsIgnoringCase("Delis") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/desserts.wav")
        }
        if inst.containsIgnoringCase("Diners") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/diners.wav")
        }
        if inst.containsIgnoringCase("Dominican") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/dominican.wav")
        }
        if inst.containsIgnoringCase("Ecuadorian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/ecuadorian.wav")
        }
        if inst.containsIgnoringCase("Egyptian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/egyptian.wav")
        }
        if inst.containsIgnoringCase("El-Savadoran") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/el-savadoarn.wav")
        }
        if inst.containsIgnoringCase("Ethiopian") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/ethiopian.wav")
        }
        if inst.containsIgnoringCase("Ethnic") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/ethnic.wav")
        }
        if inst.containsIgnoringCase("Expensive") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/expensive.wav")
        }
        if inst.containsIgnoringCase("Fast Food") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/fast-food.wav")
        }
        if inst.containsIgnoringCase("Filipino") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/filipino.wav")
        }
        if inst.containsIgnoringCase("Fine Dining") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/find-dining.wav")
        }
        if inst.containsIgnoringCase("Food Truck") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/food-trucks.wav")
        }
        if inst.containsIgnoringCase("French") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/french.wav")
        }
        if inst.containsIgnoringCase("Yogurt") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/frozen-yogurt.wav")
        }
        if inst.containsIgnoringCase("Gluten Free") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/gluten-free.wav")
        }
        if inst.containsIgnoringCase("Greek") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/greek.wav")
        }
        if inst.containsIgnoringCase("Grocery Items") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/grocery-items.wav")
        }
        if inst.containsIgnoringCase("Grocery") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/grocery.wav")
        }
        if inst.containsIgnoringCase("Halal") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/halal.wav")
        }
        if inst.containsIgnoringCase("Hamburger") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)FoodFinder-Statements/hamburger.wav")
        }
        
        // Distance Statements
        if inst.containsIgnoringCase("feet") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/feet.wav")
        }
        if inst.containsIgnoringCase("foot") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/foot.wav")
        }
        if inst.containsIgnoringCase("kilometer") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/kilometer.wav")
        }
        if inst.containsIgnoringCase("kilometers") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/kilometers.wav")
        }
        if inst.containsIgnoringCase("meter") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/meter.wav")
        }
        if inst.containsIgnoringCase("meters") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/meters.wav")
        }
        if inst.containsIgnoringCase("mile") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/mile.wav")
        }
        if inst.containsIgnoringCase("miles") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/miles.wav")
        }
        if inst.containsIgnoringCase("milimeter") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/milimeter.wav")
        }
        if inst.containsIgnoringCase("milimeters") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/milimeters.wav")
        }
        if inst.containsIgnoringCase("minute") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/minute1.wav")
        }
        if inst.containsIgnoringCase("minutes") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/minutes2.wav")
        }
        if inst.containsIgnoringCase("yard") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/yard.wav")
        }
        if inst.containsIgnoringCase("yards") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)Distance-Statements/yards.wav")
        }
        
        // Fractional Numbers
        if inst.containsIgnoringCase(".1") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.1.wav")
        }
        else if inst.containsIgnoringCase(".2") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.2.wav")
        }
        else if inst.containsIgnoringCase(".3") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.3.wav")
        }
        else if inst.containsIgnoringCase(".4") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.4.wav")
        }
        else if inst.containsIgnoringCase(".5") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.5.wav")
        }
        else if inst.containsIgnoringCase(".6") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.6.wav")
        }
        else if inst.containsIgnoringCase(".7") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.7.wav")
        }
        else if inst.containsIgnoringCase(".8") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.8.wav")
        }
        else if inst.containsIgnoringCase(".9") {
            self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/0.9.wav")
        }
        
        // Number Statements 1000 to 0
        for sNo in strNumbers {
            if inst.contains(sNo) {
                self.AddAudioToQueue(ofUrl: "\(BaseUrlSounds)1-10_fractional/\(sNo).wav")
                break
            }
        }
        
        StartPlaying()
    }
    
    func AddAudioToQueue(ofUrl url:String?)
    {
        print("AddAudioToQueue : \(url)")
        
        guard let urlString = url else {
            return
        }
        
        //var isFoundFromLocal = false
        if (urlString.containsIgnoringCase("http://")
            || urlString.containsIgnoringCase("https://"))
            && urlString.containsIgnoringCase(".wav")
        {
            print(urlString.substringWithLastInstanceOf("/"))
            if let soundName = urlString.substringWithLastInstanceOf("/")
                where NSBundle.mainBundle().URLForResource(soundName, withExtension: "wav") != nil
            {
                print(" Local Resource : - \(NSBundle.mainBundle().URLForResource(soundName, withExtension: "wav"))")
                if let AudioIdem = AudioItem(soundURLs: [AudioQuality.Medium : NSURL(string: NSBundle.mainBundle().URLForResource(soundName, withExtension: "wav")!.absoluteString)!]) {
                    AudioItems?.append(AudioIdem)
                }
                return
            }
        }
        
        if let mp3Url = NSURL(string: urlString) {
            //mp3Urls.append(mp3Url)
            if let AudioIdem = AudioItem(soundURLs: [AudioQuality.Medium : mp3Url]) {
                AudioItems?.append(AudioIdem)
            }
        }
    }
    
    func StartPlaying() {
        
        //AudioItems to play multiple audio in queue
        guard let AudioItems1 = AudioItems where AudioItems1.count > 0 else {
            return
        }
        player.stop()
        player.mode = .NoRepeat
        player.playItems(AudioItems1, startAtIndex: 0)
        
        //AVPlayer to play single audio
//        guard let mp3Url = AudioItems1.first else {
//            return
//        }
//        print("playing soung for url : \(mp3Url)")
//        do {
//
//            let playerItem = AVPlayerItem(URL: mp3Url.mediumQualityURL.URL)
//
//            self.audioPlayer = try AVPlayer(playerItem:playerItem)
//            audioPlayer?.volume = 1.0
//            audioPlayer?.play()
//        } catch let error as NSError {
//            self.audioPlayer = nil
//            print(error.localizedDescription)
//        } catch {
//            print("AVAudioPlayer init failed")
//        }
    }
    
    
    @IBAction func ClickToGo(sender: AnyObject?)
    {
        // WARNING :: TO TEST ONLY
        // self.playSoundForInstruction("Turn left Burgerking to continue on US-101")
        
        if (self.btnStartRoute.enabled
            && self.btnStartRoute.tag == 2)
            || isRouteStarted
        {
            self.btnStartRoute.setTitle("Start Route", forState: .Normal)
            self.btnStartRoute.backgroundColor = clrRed
            self.btnStartRoute.tag = 1;
            
            print("stop monitoring route")
            stopObservingRoute()
        }
        
        if isValidPincode()
        {
            if CLocation?.coordinate.latitude == 0
                && CLocation?.coordinate.longitude == 0
            {
                CLocation = LocationManager.sharedInstance.CLocation
            }
            
            //(from: txtFrom.text!, to: txtTo.text!)
            let from = (txtFrom.text! == "Current Location") ? "\(CLocation!.coordinate.latitude),\(CLocation!.coordinate.longitude)" : txtFrom.text!
            mapManager.directionsUsingGoogle(from: from, to: txtTo.text!) { (route,encodedPolyLine ,directionInformation, boundingRegion, error) -> () in
                
                if(error != nil)
                {
                    print(error)
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue())
                    {
                        self.btnGetDirection.enabled = true
                        self.btnGetDirection.backgroundColor = clrRed
                        self.btnStartRoute.enabled = true
                        self.btnStartRoute.backgroundColor = clrRed
                        self.btnStartRoute.tag = 1;
                        
                        let start_location = directionInformation?.objectForKey("start_location") as! NSDictionary
                        let originLat = start_location.objectForKey("lat")?.doubleValue
                        let originLng = start_location.objectForKey("lng")?.doubleValue
                        
                        let end_location = directionInformation?.objectForKey("end_location") as! NSDictionary
                        let destLat = end_location.objectForKey("lat")?.doubleValue
                        let destLng = end_location.objectForKey("lng")?.doubleValue
                        
                        let coordOrigin = CLLocationCoordinate2D(latitude: originLat!, longitude: originLng!)
                        let coordDesitination = CLLocationCoordinate2D(latitude: destLat!, longitude: destLng!)
                        
                        let markerOrigin = GMSMarker()
                        markerOrigin.groundAnchor = CGPoint(x: 0.5, y: 1)
                        markerOrigin.appearAnimation = kGMSMarkerAnimationPop
                        markerOrigin.icon = UIImage(named: "default_marker.png")
                        markerOrigin.title = directionInformation?.objectForKey("start_address") as! NSString as String
                        markerOrigin.snippet = directionInformation?.objectForKey("duration") as! NSString as String
                        markerOrigin.position = coordOrigin
                        
                        let markerDest = GMSMarker()
                        markerDest.groundAnchor = CGPoint(x: 0.5, y: 1)
                        markerDest.appearAnimation = kGMSMarkerAnimationPop
                        markerDest.icon = UIImage(named: "default_marker.png")
                        markerDest.title = directionInformation?.objectForKey("end_address") as! NSString as String
                        markerDest.snippet = directionInformation?.objectForKey("distance") as! NSString as String
                        markerDest.position = coordDesitination
                        
                        let camera = GMSCameraPosition.cameraWithLatitude(coordOrigin.latitude,longitude: coordOrigin.longitude, zoom: 10)
                        self.googleMapsView.animateToCameraPosition(camera)
                        
                        if let map = self.googleMapsView
                        {
                            map.clear()
                            if let encodedPolyLineStr = encodedPolyLine {
                                let path = GMSMutablePath(fromEncodedPath: encodedPolyLineStr)
                                let polyLine = GMSPolyline(path: path)
                                polyLine.strokeWidth = 5
                                polyLine.strokeColor = clrGreen
                                polyLine.map = self.googleMapsView
                            }
                            
                            markerOrigin.map = self.googleMapsView
                            markerDest.map = self.googleMapsView
                            
                            print(directionInformation)
                            self.tableData = directionInformation!
                        }
                    }
                }
            }
        }
    }
    
    func addPolyLineWithEncodedStringInMap(json: JSON)
    {
        if let routes = json["routes"].array
            where routes.count > 0
        {
            let overViewPolyLine = routes[0]["overview_polyline"]["points"].string
            print(overViewPolyLine)
            if overViewPolyLine != nil{
                //self.addPolyLineWithEncodedStringInMap(overViewPolyLine!)
                let path = GMSMutablePath(fromEncodedPath: overViewPolyLine!)
                let polyLine = GMSPolyline(path: path)
                polyLine.strokeWidth = 5
                polyLine.strokeColor = clrGreen
                polyLine.map = self.googleMapsView
            }
        } else {
            self.googleMapsView.clear()
        }
        
        
    }
    
    func isValidPincode() -> Bool {
        if txtFrom.text?.characters.count == 0
        {
            self .showAlert("Please enter your source address")
            return false
        }else if txtTo.text?.characters.count == 0
        {
            self .showAlert("Please enter your destination address")
            return false
        }
        return true
    }
    func showAlert(value:NSString)
    {
        let alert = UIAlertController(title: "Please enter your source address", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let viewController: DirectionDetailVC = segue.destinationViewController as? DirectionDetailVC {
            viewController.directionInfo = self.tableData
        }
        
        
        
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
}

// Extra Codes - UnUsed but ca use later

//-(void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//    
//    CLLocationDirection direction = newHeading.trueHeading;
//    lastDriverAngleFromNorth = direction;
//    self.driverMarker.rotation = lastDriverAngleFromNorth - mapBearing;
//}
//
//#pragma mark - GMSMapViewDelegate
//
//- (void)mapView:(GMSMapView *)mapView didChangeCameraPosition:(GMSCameraPosition *)position {
//    
//    mapBearing = position.bearing;
//    self.driverMarker.rotation = lastDriverAngleFromNorth - mapBearing;
//}
//
////just do this only
//- (void)locationManager:(CLLocationManager *)manager  didUpdateHeading:(CLHeading *)newHeading
//{
//    double heading = newHeading.trueHeading;
//    marker.groundAnchor = CGPointMake(0.5, 0.5);
//    marker.rotation = heading;
//    marker.map = mapView;
//}
