/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import UIKit
import CoreData

class AddEventViewController: UIViewController {

    @IBOutlet weak var photoUIImageView: UIImageView!
    
    @IBOutlet weak var titleEventButton: NutshellUIButton!
    @IBOutlet weak var missingPhotoView: UIView!
    @IBOutlet weak var photoIconButton: UIButton!
    @IBOutlet weak var photoIconContainer: UIView!
    
    @IBOutlet weak var titleTextField: NutshellUITextField!
    @IBOutlet weak var notesTextField: NutshellUITextField!
    
    @IBOutlet weak var eventDate: NutshellUILabel!

    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var addSuccessView: NutshellUIView!
    @IBOutlet weak var addSuccessImageView: UIImageView!

    private var eventTime = NSDate()

    //
    // MARK: - UIViewController overrides
    //

    override func viewDidLoad() {
        super.viewDidLoad()

        saveButton.hidden = true
        let df = NSDateFormatter()
        df.dateFormat = uniformDateFormat
        eventDate.text = df.stringFromDate(eventTime)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //
    // MARK: - Button and text field handlers
    //

    @IBAction func titleEventButtonHandler(sender: NutshellUIButton) {
        titleTextField.becomeFirstResponder()
        titleEventButton.hidden = true
        configureCameraImageViewUp(true)
    }
    
    // Only the notes text edit field delegate is hooked up, not the title text edit field, so this is only called for notes.
    func textFieldDidBeginEditing(textField: UITextField) {
        notesTextField.becomeFirstResponder()
        notesTextField.selectAll(nil)
    }
    
    @IBAction func titleEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
    }
    
    @IBAction func notesEditingDidEnd(sender: AnyObject) {
        updateSaveButtonState()
        notesTextField.resignFirstResponder()
    }
    
    private func updateSaveButtonState() {
        if titleTextField.text?.characters.count == 0 {
            titleEventButton.hidden = false
            saveButton.hidden = true
            configureCameraImageViewUp(false)
        } else {
            saveButton.hidden = false
        }
    }
    
    @IBAction func notesEditingDidBegin(sender: AnyObject) {
    }
    
    @IBAction func saveButtonHandler(sender: AnyObject) {
        
        if titleTextField.text == "autotest" {
            AppDelegate.testMode = true
            showSuccessView()
            return
        }
        
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            
            // This is a good place to splice in demo and test data. For now, entering "demo" as the title will result in us adding a set of demo events to the model, and "delete" will delete all food events.
            if titleTextField.text == "demo" {
                DatabaseUtils.deleteAllMealEvents(moc)
                addDemoData()
            } else if titleTextField.text == "nodemo" {
                DatabaseUtils.deleteAllMealEvents(moc)
            } else {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                
                me.location = ""
                me.title = titleTextField.text
                me.notes = notesTextField.text
                me.photo = ""
                me.type = "meal"
                me.time = eventTime // required!
                me.id = NSUUID().UUIDString // required!
                let now = NSDate()
                me.createdTime = now
                me.modifiedTime = now
                moc.insertObject(me)
            }
            
            // Save the database
            do {
                try moc.save()
                print("addEvent: Database saved!")
                showSuccessView()
            } catch let error as NSError {
                // TO DO: error message!
                print("Failed to save MOC: \(error)")
            }
        }
    }

    //
    // MARK: - Misc private funcs
    //

    private func showSuccessView() {
        let animations: [UIImage]? = [UIImage(named: "addAnimation-01")!,
            UIImage(named: "addAnimation-02")!,
            UIImage(named: "addAnimation-03")!,
            UIImage(named: "addAnimation-04")!,
            UIImage(named: "addAnimation-05")!,
            UIImage(named: "addAnimation-06")!]
        addSuccessImageView.animationImages = animations
        addSuccessImageView.animationDuration = 1.0
        addSuccessImageView.animationRepeatCount = 1
        addSuccessImageView.startAnimating()
        addSuccessView.hidden = false
        
        NutUtils.delay(1.25) {
            self.navigationController?.popViewControllerAnimated(true)
        }
    }
    
    // When the event has a title, the "Title this event" button disappears, and the photo icon is recentered in its container view. This is reversed if the title goes back to an empty string.     
    private func configureCameraImageViewUp(up: Bool) {
        print("constraints: \(photoIconContainer.constraints)")
        for c in photoIconContainer.constraints {
            if c.firstAttribute == NSLayoutAttribute.CenterY {
                c.constant = up ? 0.0 : 20.0
                break
            }
        }
        UIView.animateWithDuration(0.5) {
            self.photoIconContainer.layoutIfNeeded()
        }
    }

    //
    // MARK: - Test code!
    //

    private func addDemoData() {
        
        let demoMeals = [
            ["Three tacos", "with 15 chips & salsa", "2015-08-20T10:03:21.000Z", "home"],
            ["Three tacos", "after ballet", "2015-08-09T19:42:40.000Z", "238 Garrett St"],
            ["Three tacos", "Apple Juice before", "2015-07-29 04:55:27 +0000", "Golden Gate Park"],
            ["Three tacos", "and horchata", "2015-07-09 14:25:21 +0000", "Golden Gate Park"],
            ["Workout", "running in park", "2015-08-01T04:23:20.000Z", ""],
            ["", "Only notes for this one", "2015-08-27 08:25:21 +0000", ""],
            ["CPK 5 cheese margarita", "", "2015-08-27 12:25:21 +0000", ""],
            ["Bagel & cream cheese fruit", "", "2015-08-27 16:25:21 +0000", ""],
            ["Birthday Party", "", "2015-07-04 14:25:21 +0000", ""],
            ["Soccer Practice", "", "2015-07-03 14:25:21 +0000", ""],
            ["Meal on Aug 27", "08:25:21", "2015-08-28 08:25:21 +0000", ""],
            ["Meal on Aug 27", "12:25:21", "2015-08-28 12:25:21 +0000", ""],
            ["Meal on Aug 27", "16:25:21", "2015-08-28 16:25:21 +0000", ""],
            ["Meal on Aug 27", "20:25:21", "2015-08-28 20:25:21 +0000", ""],
            ["Meal on Aug 27", "00:25:21", "2015-08-29 00:25:21 +0000", ""],
        ]
        
        func addMeal(me: Meal, event: [String], df: NSDateFormatter) {
            me.title = event[0]
            me.notes = event[1]
            if (event[2] == "") {
                me.time = NSDate()
            } else {
                me.time = df.dateFromISOString(event[2])
            }
            me.location = event[3]
            me.photo = ""
            me.type = "meal"
            me.id = NSUUID().UUIDString // required!
            let now = NSDate()
            me.createdTime = now
            me.modifiedTime = now
        }
        
        let df = NSDateFormatter()
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate
        let moc = ad.managedObjectContext
        if let entityDescription = NSEntityDescription.entityForName("Meal", inManagedObjectContext: moc) {
            for event in demoMeals {
                let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Meal
                addMeal(me, event: event, df: df)
                moc.insertObject(me)
            }
        }
    }

}