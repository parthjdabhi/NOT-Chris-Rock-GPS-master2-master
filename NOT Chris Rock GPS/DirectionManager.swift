//
//  DirectionManager.swift
//  TYDirectionSwift
//
//  Created by Thabresh on 9/6/16.
//  Copyright © 2016 VividInfotech. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import SwiftyJSON

typealias DirectionsCompletionHandler = ((route:MKPolyline?, encodedPolyLine:String?, directionInformation:NSDictionary?, boundingRegion:MKMapRect?, error:String?)->())?

class DirectionManager: NSObject {
    private var directionsCompletionHandler:DirectionsCompletionHandler
    private let errorNoRoutesAvailable = "No routes available"// add more error handling
    
    private let errorDictionary = ["NOT_FOUND" : "At least one of the locations specified in the request's origin, destination, or waypoints could not be geocoded",
                                   "ZERO_RESULTS":"No route could be found between the origin and destination",
                                   "MAX_WAYPOINTS_EXCEEDED":"Too many waypointss were provided in the request The maximum allowed waypoints is 8, plus the origin, and destination",
                                   "INVALID_REQUEST":"The provided request was invalid. Common causes of this status include an invalid parameter or parameter value",
                                   "OVER_QUERY_LIMIT":"Service has received too many requests from your application within the allowed time period",
                                   "REQUEST_DENIED":"Service denied use of the directions service by your application",
                                   "UNKNOWN_ERROR":"Directions request could not be processed due to a server error. Please try again"]
    
    override init(){
        super.init()
    }
    
    func directions(from from:CLLocationCoordinate2D,to:NSString,directionCompletionHandler:DirectionsCompletionHandler){
        self.directionsCompletionHandler = directionCompletionHandler
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(to as String, completionHandler: { (placemarksObject, error) -> Void in
            if let error = error {
                self.directionsCompletionHandler!(route: nil, encodedPolyLine:nil,directionInformation:nil, boundingRegion: nil, error: error.localizedDescription)
            }
            else {
                let placemark = placemarksObject!.last!
                
                let placemarkSource = MKPlacemark(coordinate: from, addressDictionary: nil)
                
                let source = MKMapItem(placemark: placemarkSource)
                let placemarkDestination = MKPlacemark(placemark: placemark)
                let destination = MKMapItem(placemark: placemarkDestination)
                
                self.directionsFor(source: source, destination: destination, directionCompletionHandler: directionCompletionHandler)
            }
        })
    }
    
    func directionsFromCurrentLocation(to to:NSString,directionCompletionHandler:DirectionsCompletionHandler){
        self.directionsCompletionHandler = directionCompletionHandler
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(to as String, completionHandler: { (placemarksObject, error) -> Void in
            if let error = error {
                self.directionsCompletionHandler!(route: nil, encodedPolyLine:nil, directionInformation:nil, boundingRegion: nil, error: error.localizedDescription)
            }
            else{
                let placemark = placemarksObject!.last!
                let source = MKMapItem.mapItemForCurrentLocation()
                let placemarkDestination = MKPlacemark(placemark: placemark)
                let destination = MKMapItem(placemark: placemarkDestination)
                self.directionsFor(source: source, destination: destination, directionCompletionHandler: directionCompletionHandler)
            }
        })
    }
    
    func directionsFromCurrentLocation(to to:CLLocationCoordinate2D,directionCompletionHandler:DirectionsCompletionHandler){
        let source = MKMapItem.mapItemForCurrentLocation()
        let placemarkDestination = MKPlacemark(coordinate: to, addressDictionary: nil)
        let destination = MKMapItem(placemark: placemarkDestination)
        directionsFor(source: source, destination: destination, directionCompletionHandler: directionCompletionHandler)
    }
    
    func directions(from from:CLLocationCoordinate2D, to:CLLocationCoordinate2D,directionCompletionHandler:DirectionsCompletionHandler){
        let placemarkSource = MKPlacemark(coordinate: from, addressDictionary: nil)
        let source = MKMapItem(placemark: placemarkSource)
        let placemarkDestination = MKPlacemark(coordinate: to, addressDictionary: nil)
        let destination = MKMapItem(placemark: placemarkDestination)
        directionsFor(source: source, destination: destination, directionCompletionHandler: directionCompletionHandler)
    }
    
    private func directionsFor(source source:MKMapItem, destination:MKMapItem, directionCompletionHandler:DirectionsCompletionHandler){
        self.directionsCompletionHandler = directionCompletionHandler
        let directionRequest = MKDirectionsRequest()
        directionRequest.source = source
        directionRequest.destination = destination
        directionRequest.transportType = MKDirectionsTransportType.Any
        directionRequest.requestsAlternateRoutes = true
        let directions = MKDirections(request: directionRequest)
        directions.calculateDirectionsWithCompletionHandler({
            (response:MKDirectionsResponse?, error:NSError?) -> Void in
            if let error = error {
                self.directionsCompletionHandler!(route: nil, encodedPolyLine:nil, directionInformation:nil, boundingRegion: nil, error: error.localizedDescription)
            }
            else if response!.routes.isEmpty {
                self.directionsCompletionHandler!(route: nil, encodedPolyLine:nil, directionInformation:nil, boundingRegion: nil, error: self.errorNoRoutesAvailable)
            }
            else
            {
                
                print("\n\n :: response :: ",response)
                
                let route: MKRoute = response!.routes[0]
                let steps = route.steps as NSArray
                let end_address = route.name
                let distance = route.distance.description
                let duration = route.expectedTravelTime.description
                
                let source = response!.source.placemark.coordinate
                let destination = response!.destination.placemark.coordinate
                
                let start_location = ["lat":source.latitude,"lng":source.longitude]
                let end_location = ["lat":destination.latitude,"lng":destination.longitude]
                
                let stepsFinalArray = NSMutableArray()
                
                steps.enumerateObjectsUsingBlock({ (obj, idx, stop) -> Void in
                    let step:MKRouteStep = obj as! MKRouteStep
                    let distance = step.distance.description
                    let instructions = step.instructions
                    let stepsDictionary = NSMutableDictionary()
                    
                    stepsDictionary.setObject(distance, forKey: "distance")
                    stepsDictionary.setObject("", forKey: "duration")
                    stepsDictionary.setObject(instructions, forKey: "instructions")
                    
                    stepsFinalArray.addObject(stepsDictionary)
                })
                
                let stepsDict = NSMutableDictionary()
                stepsDict.setObject(distance, forKey: "distance")
                stepsDict.setObject(duration, forKey: "duration")
                stepsDict.setObject(end_address, forKey: "end_address")
                stepsDict.setObject(end_location, forKey: "end_location")
                stepsDict.setObject("", forKey: "start_address")
                stepsDict.setObject(start_location, forKey: "start_location")
                stepsDict.setObject(stepsFinalArray, forKey: "steps")
                
                self.directionsCompletionHandler!(route: route.polyline, encodedPolyLine:nil, directionInformation: stepsDict, boundingRegion: route.polyline.boundingMapRect, error: nil)
            }
        })
    }
    
    /**
     Get directions using Google API by passing source and destination as string.
     - parameter from: Starting point of journey
     - parameter to: Ending point of journey
     - returns: directionCompletionHandler: Completion handler contains polyline,dictionary,maprect and error
     */
    func directionsUsingGoogle(from from:NSString, to:NSString,directionCompletionHandler:DirectionsCompletionHandler){
        getDirectionsUsingGoogle(origin: from, destination: to, directionCompletionHandler: directionCompletionHandler)
    }
    
    func directionsUsingGoogle(from from:CLLocationCoordinate2D, to:CLLocationCoordinate2D,directionCompletionHandler:DirectionsCompletionHandler)
    {
        let originLatLng = "\(from.latitude),\(from.longitude)"
        let destinationLatLng = "\(to.latitude),\(to.longitude)"
        getDirectionsUsingGoogle(origin: originLatLng, destination: destinationLatLng, directionCompletionHandler: directionCompletionHandler)
        
    }
    
    func directionsUsingGoogle(from from:CLLocationCoordinate2D, to:NSString,directionCompletionHandler:DirectionsCompletionHandler){
        let originLatLng = "\(from.latitude),\(from.longitude)"
        getDirectionsUsingGoogle(origin: originLatLng, destination: to, directionCompletionHandler: directionCompletionHandler)
    }
    
    private func getDirectionsUsingGoogle(origin origin:NSString, destination:NSString,directionCompletionHandler:DirectionsCompletionHandler){
        self.directionsCompletionHandler = directionCompletionHandler
        let path = "http://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)"
        performOperationForURL(path)
    }
    
    private func performOperationForURL(urlString:NSString){
//        let directionURL = "https://maps.googleapis.com/maps/api/directions/json?origin=\(CLocation!.coordinate.latitude),\(CLocation!.coordinate.longitude)&destination=\(CLocationSelected.coordinate.latitude),\(CLocationSelected.coordinate.longitude)&key=\(googleMapsApiKey)&mode=driving"
//        //mode:driving,walking,bicycling,transit
//        print(directionURL)
        
        print("\n\n :: urlString :: ",urlString)
        
        //var urlEncoded = urlString.stringByReplacingOccurrencesOfString(" ", withString: "%20")
        let urlEncoded = urlString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let url:NSURL? = NSURL(string:urlEncoded)
        let request:NSURLRequest = NSURLRequest(URL:url!)
        let queue:NSOperationQueue = NSOperationQueue()
        
        NSURLConnection.sendAsynchronousRequest(request,queue:queue,completionHandler:{response,data,error in
            if error != nil {
                print(error!.localizedDescription)
                self.directionsCompletionHandler!(route: nil, encodedPolyLine:nil, directionInformation:nil, boundingRegion: nil, error: error!.localizedDescription)
            }
            else{
                let jsonResult: NSDictionary = (try! NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers)) as! NSDictionary
                //let json = JSON(data!)
                
                //https://roads.googleapis.com/v1/speedLimits?placeId=ChIJ1Wi6I2pNFmsRQL9GbW7qABM&key=AIzaSyB5jzZt5pc9-WVIEvfaBIZAIvQOYLhVu94
                
                //https://maps.googleapis.com/maps/api/place/details/json?placeid=ChIJn2PA6faAhYARrJbJ4MeKbzc&key=AIzaSyB5jzZt5pc9-WVIEvfaBIZAIvQOYLhVu94
                
                //https://maps.googleapis.com/maps/api/place/details/json?reference=CmRYAAAAciqGsTRX1mXRvuXSH2ErwW-jCINE1aLiwP64MCWDN5vkXvXoQGPKldMfmdGyqWSpm7BEYCgDm-iv7Kc2PF7QA7brMAwBbAcqMr5i1f4PwTpaovIZjysCEZTry8Ez30wpEhCNCXpynextCld2EBsDkRKsGhSLayuRyFsex6JA6NPh9dyupoTH3g&key=AIzaSyB5jzZt5pc9-WVIEvfaBIZAIvQOYLhVu94
                
                print(jsonResult)
                print(jsonResult.objectForKey("status"))
                let routes = jsonResult.objectForKey("routes") as! NSArray
                let status = jsonResult.objectForKey("status") as! NSString
                if routes.count > 0 {
                    let route = routes.lastObject as! NSDictionary //first object?
                    if status.isEqualToString("OK") && route.allKeys.count > 0  {
                        let legs = route.objectForKey("legs") as! NSArray
                        let steps = legs.firstObject as! NSDictionary
                        let directionInformation = self.parser(steps) as NSDictionary
                        let overviewPolyline = route.objectForKey("overview_polyline") as! NSDictionary
                        let points = overviewPolyline.objectForKey("points") as! NSString
//                        let locations = self.decodePolyLine(points) as Array
//                        var coordinates = locations.map({ (location: CLLocation) ->
//                            CLLocationCoordinate2D in
//                            return location.coordinate
//                        })
//                        let polyline = MKPolyline(coordinates: &coordinates, count: locations.count)
                        
                        let poly = self.polyLineWithEncodedString(points as String)
//                        var overViewPolyLine:String?
//                        if let routes = json["routes"].array
//                            where routes.count > 0
//                        {
//                            overViewPolyLine = routes[0]["overview_polyline"]["points"].string
//                        }
                        
                        self.directionsCompletionHandler!(route: poly, encodedPolyLine:points as String, directionInformation:directionInformation, boundingRegion: poly.boundingMapRect, error: nil)
                    }
                }
                else
                {
                    var errorMsg = self.errorDictionary[status as String]
                    if errorMsg == nil {
                        errorMsg = self.errorNoRoutesAvailable
                    }
                    
                    self.directionsCompletionHandler!(route: nil, encodedPolyLine:nil, directionInformation:nil, boundingRegion: nil, error: errorMsg)
                }
            }
        })
    }
    
    private func decodePolyLine(encodedStr:NSString)->Array<CLLocation>{
        var array = Array<CLLocation>()
        let len = encodedStr.length
        let range = NSMakeRange(0, len)
        var strpolyline = encodedStr
        var index = 0
        var lat = 0 as Int32
        var lng = 0 as Int32
        
        strpolyline = encodedStr.stringByReplacingOccurrencesOfString("\\\\", withString: "\\", options: NSStringCompareOptions.LiteralSearch, range: range)
        while(index<len){
            var b = 0
            var shift = 0
            var result = 0
            repeat {
                let numUnichar = strpolyline.characterAtIndex(index++)
                let num =  NSNumber(unsignedShort: numUnichar)
                let numInt = num.integerValue
                b = numInt - 63
                result |= (b & 0x1f) << shift
                shift += 5
            } while(b >= 0x20)
            
            var dlat = 0
            
            if((result & 1) == 1){
                dlat = ~(result >> 1)
            }
            else{
                dlat = (result >> 1)
            }
            
            lat += dlat
            
            shift = 0
            result = 0
            
            repeat {
                let numUnichar = strpolyline.characterAtIndex(index++)
                let num =  NSNumber(unsignedShort: numUnichar)
                let numInt = num.integerValue
                b = numInt - 63
                result |= (b & 0x1f) << shift
                shift += 5
            } while(b >= 0x20)
            
            var dlng = 0
            
            if((result & 1) == 1){
                dlng = ~(result >> 1)
            }
            else{
                dlng = (result >> 1)
            }
            lng += dlng
            
            let latitude = NSNumber(int:lat).doubleValue * 1e-5
            let longitude = NSNumber(int:lng).doubleValue * 1e-5
            let location = CLLocation(latitude: latitude, longitude: longitude)
            array.append(location)
        }
        return array
    }
    
    func polyLineWithEncodedString(encodedString: String) -> MKPolyline {
        let bytes = (encodedString as NSString).UTF8String
        let length = encodedString.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        var idx: Int = 0
        
        var count = length / 4
        var coords = UnsafeMutablePointer<CLLocationCoordinate2D>.alloc(count)
        var coordIdx: Int = 0
        
        var latitude: Double = 0
        var longitude: Double = 0
        
        while (idx < length) {
            var byte = 0
            var res = 0
            var shift = 0
            
            repeat {
                byte = bytes[idx++] - 0x3F
                res |= (byte & 0x1F) << shift
                shift += 5
            } while (byte >= 0x20)
            
            let deltaLat = ((res & 1) != 0x0 ? ~(res >> 1) : (res >> 1))
            latitude += Double(deltaLat)
            
            shift = 0
            res = 0
            
            repeat {
                byte = bytes[idx++] - 0x3F
                res |= (byte & 0x1F) << shift
                shift += 5
            } while (byte >= 0x20)
            
            let deltaLon = ((res & 1) != 0x0 ? ~(res >> 1) : (res >> 1))
            longitude += Double(deltaLon)
            
            let finalLat: Double = latitude * 1E-5
            let finalLon: Double = longitude * 1E-5
            
            let coord = CLLocationCoordinate2DMake(finalLat, finalLon)
            coords[coordIdx++] = coord
            
            if coordIdx == count {
                let newCount = count + 10
                let temp = coords
                coords.dealloc(count)
                coords = UnsafeMutablePointer<CLLocationCoordinate2D>.alloc(newCount)
                for index in 0..<count {
                    coords[index] = temp[index]
                }
                temp.destroy()
                count = newCount
            }
            
        }
        
        let polyLine = MKPolyline(coordinates: coords, count: coordIdx)
        coords.destroy()
        
        return polyLine
    }
    
    private func parser(data:NSDictionary)->NSDictionary{
        let distance = (data.objectForKey("distance") as! NSDictionary).objectForKey("text") as! NSString
        let duration = (data.objectForKey("duration") as! NSDictionary).objectForKey("text") as! NSString
        let end_address = data.objectForKey("end_address") as! NSString
        let end_location = data.objectForKey("end_location") as! NSDictionary
        let start_address = data.objectForKey("start_address") as! NSString
        let start_location = data.objectForKey("start_location") as! NSDictionary
        let stepsArray = data.objectForKey("steps") as! NSArray
        let stepsDict = NSMutableDictionary()
        let stepsFinalArray = NSMutableArray()
        
        stepsArray.enumerateObjectsUsingBlock { (obj, idx, stop) -> Void in
            let stepDict = obj as! NSDictionary
            let distance = (stepDict.objectForKey("distance") as! NSDictionary).objectForKey("text") as! NSString
            let duration = (stepDict.objectForKey("duration") as! NSDictionary).objectForKey("text") as! NSString
            let html_instructions = stepDict.objectForKey("html_instructions") as! NSString
            let end_location = stepDict.objectForKey("end_location") as! NSDictionary
            let instructions = self.removeHTMLTags((stepDict.objectForKey("html_instructions") as! NSString))
            let start_location = stepDict.objectForKey("start_location") as! NSDictionary
            let stepsDictionary = NSMutableDictionary()
            stepsDictionary.setObject(distance, forKey: "distance")
            stepsDictionary.setObject(duration, forKey: "duration")
            stepsDictionary.setObject(html_instructions, forKey: "html_instructions")
            stepsDictionary.setObject(end_location, forKey: "end_location")
            stepsDictionary.setObject(instructions, forKey: "instructions")
            stepsDictionary.setObject(start_location, forKey: "start_location")
            stepsFinalArray.addObject(stepsDictionary)
        }
        
        stepsDict.setObject(distance, forKey: "distance")
        stepsDict.setObject(duration, forKey: "duration")
        stepsDict.setObject(end_address, forKey: "end_address")
        stepsDict.setObject(end_location, forKey: "end_location")
        stepsDict.setObject(start_address, forKey: "start_address")
        stepsDict.setObject(start_location, forKey: "start_location")
        stepsDict.setObject(stepsFinalArray, forKey: "steps")
        
        return stepsDict
    }
    
    private func removeHTMLTags(source:NSString)->NSString{
        var range = NSMakeRange(0, 0)
        let HTMLTags = "<[^>]*>"
        
        var sourceString = source
        while( sourceString.rangeOfString(HTMLTags, options: NSStringCompareOptions.RegularExpressionSearch).location != NSNotFound){
            range = sourceString.rangeOfString(HTMLTags, options: NSStringCompareOptions.RegularExpressionSearch)
            sourceString = sourceString.stringByReplacingCharactersInRange(range, withString: "")
        }
        return sourceString;
    }
}


