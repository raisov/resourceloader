#  ResourceLoader
ResourceLoader is a Swift library intended to asynchronously load resources identified by URL. It was designed to perform a practical challenge from the Mindvalley.

## Overview

## Usage
```swift
import ResourceLoader
```
Loadable resources should have a type  conforming to the protocol `CreatableFromData`. To ensure conformancy, a type must have an `init?(data: Data)` constructor.

Conformance can easily be provided for types such as UIImage (NSImage), XMLParser and PDFDocument by extensions like:
 ```swift
    extension UIImage: CreatableFromData {}
```
For the representation of JSON resources the types `JSONObject` and `JSONArray` are defined in a library having a `value` properties of type `[String : Any] and [Any], respectively.

First of all the instance of `URLLoader` should be created, specialized to resource type.
```swift
let imageLoader = URLLoader<UIImage>()
```
Method  `requestResource(url:acceptor:)` is used to start the download.

