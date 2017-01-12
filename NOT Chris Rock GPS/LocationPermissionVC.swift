//
//  LocationPermissionVC.swift
//  NOT Chris Rock GPS
//
//  Created by iParth on 1/12/17.
//  Copyright © 2017 Harloch. All rights reserved.
//

import UIKit

class LocationPermissionVC: UIViewController {

    @IBOutlet weak var lblMessage: UILabel!
    @IBOutlet weak var btnSetting: UIButton!
    
    var actionChangeSetting: blockAction?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        
        //Check For Updated permission
        //if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.Denied {
            //self.navigationController?.popViewControllerAnimated(true)
        //}
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    
    @IBAction func actionSettingButton(sender: AnyObject) {
        
        UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        
    }
    
    @IBAction func actionDismissButton(sender: AnyObject) {
        
        dismissViewControllerAnimated(true, completion: nil)
        
    }
    
}
