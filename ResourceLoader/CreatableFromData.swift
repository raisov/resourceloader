//
//  CreatableFromData.swift
//  ResourceLoader
//
//  Created by bp on 2018-09-28.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

/// The resources loadable by the `ULLoader` should be represented by the type
/// conforming to the protocol `CreatableFromData`.
/// To ensure conformancy, a type must have an `init?(data: Data)` constructor.
/// Conformance can easily be provided for types
/// such as {UIImage, XMLParser and PDFDocument by extensions like:
/// ```
///    extension UIImage: CreatableFromData {}
/// ```
/// For the representation of JSON resources
/// the types `JSONObject` and `JSONArray` are defined below
/// having a `value` properties of type
/// `[String : Any] and [Any], respectively.
public protocol CreatableFromData {
    init?(data: Data)
}

public struct JSONObject: CreatableFromData {
    public let value: [String: Any]
    public init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        guard let dictionary =  json as? [String: Any] else {
            return nil
        }
        self.value = dictionary
    }
}

public struct JSONArray: CreatableFromData {
    public let value: [Any]
    public init?(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        guard let array =  json as? [Any] else {
            return nil
        }
        self.value = array
    }
}
