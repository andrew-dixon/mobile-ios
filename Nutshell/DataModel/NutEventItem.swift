//
//  NutEventItem.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/6/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import UIKit

class NutEventItem {
    
    var title: String
    var location: String
    var notes: String
    var time: Date
    var tzOffsetSecs: Int
    var nutCracked: Bool = false
    var eventItem: EventItem
    
    init(eventItem: EventItem) {
        self.eventItem = eventItem
        self.title = eventItem.title ?? ""
        self.location = ""
        self.notes = eventItem.notes ?? ""
        if eventItem.nutCracked != nil {
            self.nutCracked = Bool(eventItem.nutCracked!)
        }
        
        if let eventTime = eventItem.time {
            self.time = eventTime as Date
        } else {
            self.time = Date()
            NSLog("ERROR: nil time leaked in for event \(self.title)")
        }
            
        if let zoneOffset = eventItem.timezoneOffset {
            self.tzOffsetSecs = Int(zoneOffset) * 60
        } else {
            self.tzOffsetSecs = NSCalendar.current.timeZone.secondsFromGMT()
            NSLog("ERROR: nil time zone offset for \(self.title)")
        }
    }
    
    func nutEventIdString() -> String {
        // TODO: this will alias:
        //  title: "My NutEvent at Home", loc: "" with
        //  title: "My NutEvent at ", loc: "Home"
        // But for now consider this a feature...
        return self.prefix()  + title + location
    }
    
    func prefix() -> String {
        // Subclass!
        return ""
    }
    
    func containsSearchString(_ searchString: String) -> Bool {
        if notes.localizedCaseInsensitiveContains(searchString) {
            return true
        }
        return false;
    }
    
    // true if item changed and was successfully saved...
    func saveChanges() -> Bool {
        if changed() {
            copyChanges()
            if let moc = eventItem.managedObjectContext {
                eventItem.modifiedTime = Date()
                eventItem.userid = NutDataController.sharedInstance.currentUserId // Should already be set but can't hurt
                moc.refresh(eventItem, mergeChanges: true)
                return DatabaseUtils.databaseSave(moc)
            }
        }
        return false
    }

    func deleteItem() -> Bool {
        if let moc = eventItem.managedObjectContext {
            moc.delete(self.eventItem)
            return DatabaseUtils.databaseSave(moc)
        }
        return false
    }

    //
    // MARK: - Override in subclasses!
    //

    func changed() -> Bool {
        let currentTitle = eventItem.title ?? ""
        if currentTitle != title {
            return true
        }
        let currentNotes = eventItem.notes ?? ""
        if currentNotes != notes {
            return true
        }
        if eventItem.nutCracked == nil || nutCracked != Bool(eventItem.nutCracked!) {
            return true
        }
        if eventItem.time == nil || time != eventItem.time {
            return true
        }
        if eventItem.userid == nil {
            NSLog("Found nut event with no userId!")
            return true
        }
        return false
    }
 
    func copyChanges() {
        eventItem.title = title
        eventItem.notes = notes
        eventItem.nutCracked = nutCracked as NSNumber?
        eventItem.time = time
    }
    
    func firstPictureUrl() -> String {
        return ""
    }

    func photoUrlArray() -> [String] {
        return []
    }

}

func != (left: NutEventItem, right: NutEventItem) -> Bool {
    // TODO: if we had an id, we could just check that!
    return ((left.notes != right.notes) || (left.time != right.time))
}

