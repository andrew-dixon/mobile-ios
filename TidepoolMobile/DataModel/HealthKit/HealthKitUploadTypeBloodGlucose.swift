/*
 * Copyright (c) 2018, Tidepool Project
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

import Foundation
import CocoaLumberjack
import HealthKit

class HealthKitUploadTypeBloodGlucose: HealthKitUploadType {
    init() {
        super.init("BloodGlucose")
    }

    // MARK: Overrides!
    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
    }

    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        // For now, don't filter anything out!
        return sortedSamples

//        // Filter out non-Dexcom data
//        var filteredSamples = [HKSample]()
//
//        for sample in sortedSamples {
//            let sourceRevision = sample.sourceRevision
//            let source = sourceRevision.source
//            let treatAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
//            if source.name.lowercased().range(of: "dexcom") == nil && !treatAllBloodGlucoseSourceTypesAsDexcom {
//                DDLogInfo("Ignoring non-Dexcom glucose data from source: \(source.name)")
//                continue
//            }
//
//            filteredSamples.append(sample)
//        }
//        
//        return filteredSamples
    }
    
    /// Whitelist for now to distinguish "cbg" types: all others are assumed to be "smbg"
    private func determineTypeOfBG(_ sample: HKQuantitySample) -> String {
        let bundleIdSeparators = CharacterSet(charactersIn: ".")
        let whiteListSources = [
            "Loop" : true,
            "BGMTool" : true,
            ]
        let whiteListBundleIds = [
            "com.dexcom.Share2" : true,
            "com.dexcom.CGM" : true,
            "com.dexcom.G6" : true,
            ]
        let whiteListBundleComponents = [
            "loopkit" : true
        ]
        let kTypeCbg = "cbg"
        let kTypeSmbg = "smbg"
        
        // First check whitelisted sources for those we know are cbg sources...
        let sourceName = sample.sourceRevision.source.name
        if whiteListSources[sourceName] != nil {
            return kTypeCbg
        }
        
        // Also mark glucose data from HK as CGM data if any of the following are true:
        // (1) HKSource.bundleIdentifier is one of the following: com.dexcom.Share2, com.dexcom.CGM, or com.dexcom.G6.

        let bundleId = sample.sourceRevision.source.bundleIdentifier
        if whiteListBundleIds[bundleId] != nil {
            return kTypeCbg
        }
        
        // (2) HKSource.bundleIdentifier ends in .Loop
        if bundleId.hasSuffix(".Loop") {
            return kTypeCbg
        }
                
        // (3) HKSource.bundleIdentifier has loopkit as one of the (dot separated) components
        let bundleIdComponents = bundleId.components(separatedBy: bundleIdSeparators)
        for comp in bundleIdComponents {
            if whiteListBundleComponents[comp] != nil {
                return kTypeCbg
            }
        }
        
        // Assume everything else is smbg!
        return kTypeSmbg
    }

    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        //DDLogInfo("blood glucose prepareDataForUpload")
        //let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        filterLoop: for sample in data.filteredSamples {
            if let quantitySample = sample as? HKQuantitySample {
                var sampleToUploadDict = [String: AnyObject]()
                let bgType = determineTypeOfBG(quantitySample)
                sampleToUploadDict["type"] = bgType as AnyObject?
 
                // Add fields common to all types: guid, deviceId, time, and origin
                super.addCommonFields(sampleToUploadDict: &sampleToUploadDict, sample: sample)
                let units = "mg/dL"
                sampleToUploadDict["units"] = units as AnyObject?
                let unit = HKUnit(from: units)
                let value = quantitySample.quantity.doubleValue(for: unit)
                // service syntax check: [required; 0 <= value <= 1000]
                if value < 0 || value > 1000 {
                    //TODO: log this some more obvious way?
                    DDLogError("Blood glucose sample with out-of-range value: \(value)")
                    continue filterLoop
                }
                sampleToUploadDict["value"] = value as AnyObject?
                //DDLogInfo("blood glucose value: \(String(describing: value))")
                
                // Add out-of-range annotation if needed
                var annotationCode: String?
                var annotationValue: String?
                var annotationThreshold = 0
                if (value < 40) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "low"
                    annotationThreshold = 40
                } else if (value > 400) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "high"
                    annotationThreshold = 400
                }
                if let annotationCode = annotationCode,
                    let annotationValue = annotationValue {
                    let annotations = [
                        [
                            "code": annotationCode,
                            "value": annotationValue,
                            "threshold": annotationThreshold
                        ]
                    ]
                    sampleToUploadDict["annotations"] = annotations as AnyObject?
                }

                if var metadata = sample.metadata {
                    if bgType == "smbg" {
                        // If the blood glucose data point is NOT from a whitelisted cbg source AND is flagged in HealthKit as HKMetadataKeyWasUserEntered, then label it as subtype = manual
                        if let wasUserEntered = metadata[HKMetadataKeyWasUserEntered] as? Bool {
                            if wasUserEntered {
                                sampleToUploadDict["subType"] = "manual" as AnyObject?
                            }
                        }
                    }
                    // Special case for Dexcom, if "Receiver Display Time" exists, pass that as deviceTime and remove from metadata payload
                    if let receiverTime = metadata["Receiver Display Time"] {
                        if let date = receiverTime as? Date {
                            let formattedDate = dateFormatter.isoStringFromDate(date, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                            sampleToUploadDict["deviceTime"] = formattedDate as AnyObject?
                            metadata.removeValue(forKey: "Receiver Display Time")
                        }
                    }

                    // Add remaining metadata, if any, as payload struct
                    addMetadata(&metadata, sampleToUploadDict: &sampleToUploadDict)
                }
                
                // Add sample
                samplesToUploadDictArray.append(sampleToUploadDict)
            } else {
                DDLogError("Encountered HKSample that was not an HKQuantitySample!")
            }
        }
        return samplesToUploadDictArray
    }
}

