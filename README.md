#  ResourceLoader

__ResourceLoader__ is a Swift library intended to asynchronously load resources identified by URL.

## Overview

This library was designed to completing the practical challenge from potential  employer. Below is a brief description of the task.

### Task

Your task is to create an image loading library that will be used to asynchronously download the images for the pins on the pinboard when they are needed.

The purpose of the library is to abstract the downloading (images, pdf, zip, etc) and caching of remote resources (images, JSON, XML, etc) so that client code can easily "swap" a URL for any kind of files ( JSON, XML, etc) without worrying about any of the details. Resources which are reused often should not be continually re-downloaded and should be cached, but the library cannot use infinite memory.

### Requirements

* Use the following url for loading data: http://pastebin.com/raw/wgkJgazE
* Images and JSON should be cached efficiently (in-memory only, no need for caching to disk);
* The cache should have a configurable max capacity and should evict images not recently used;
* An image load may be cancelled;
* The same image may be requested by multiple sources simultaneously (even before it has loaded), and if one of the sources cancels the load, it should not affect the remaining requests;
* Multiple distinct resources may be requested in parallel;
* You can work under the assumption that the same URL will always return the same resource.
* The library should be easy to integrate into new iOS project / apps.

### Solution

The library is designed in accordance with these requirements. It contains some unit tests for loading JPEG, PNG, XML, PDF and JSON resources. 

In addition, LoaderDemo iOS application was developed to demonstrate the use of the library.


## Usage
```swift
import ResourceLoader
```
Loadable resources should have a type  conforming to the custom protocol [`CreatableFromData`](./ResourceLoader/CreatableFromData.swift). To ensure conformancy, a type must have an `init?(data: Data)` constructor.

Conformance can easily be provided for types such as UIImage (NSImage), XMLParser and PDFDocument by extensions like:
 ```swift
    extension UIImage: CreatableFromData {}
```
For the representation of JSON resources the types `JSONObject` and `JSONArray` are defined in a library having a `value` properties of type `[String : Any] and [Any], respectively.

First of all the instance of `URLLoader` should be created, specialized to resource type.
```swift
let imageLoader = URLLoader<UIImage>()
```
Method  `requestResource(url:userData:acceptor:)` is used to start the asynchronous download from the specified URL. When request is finished, closure specifies by `acceptor` parameter will be called. This closure receives three parameters:

* loaded resource of specified type (may be nil when error ocured during loading);
* descriptor of complited request (which, by the way) has `url` property);
* arbitrary user data that have been specified in corresponding `requestResource` call.

Method returns request descriptor, uniquely identified request in a scope of URLLoader instance.

For example, to download image and display it in `UIImageView`:

```swift
import UIKit
import ResourceLoader

extension UIImage: CreatableFromData {}
// ...
let imageView: UIImageView
// ...
let imageLoader = URLLoader<UIImage>()
let url = URL( /* ... */ )
let requestId = imageLoader.requestResource(url: url, userData: imageView) {
    image, _, view in
    if let image = image {
        view.image = image
    } else {
        // error
    }
}

```
`URLLoader` has a `cancelRequest` method also. Then to cancel request above:

```
imageLoader.cancelRequest(requestId)
```

In the following example the list of user names loaded from JSON like this:

```json
[
   {"user" : "jsmith", "firstname" : "John", "lastname" : "Smith"},
   {"user" : "ivanov", "firstname" : "Ivan", "lastname" : "Ivanov"}
]    
```

```swift
import Foundation
import ResourceLoader

let loader = URLLoader<JSONArray>()
let jsonURL = URL( /* ... */ )
var usernames = [String]()
loader.requestResource(url: jsonURL) {json, _, _ in
    guard let json = json else {/*error*/ return}
    usernames = json.value.compactMap {
        $0 as? [String : Any]
    }.compactMap {
        $0["user"] as? String]
    }
}
// usernames == ["jmith", "ivanov"]
```

## Integration

After you clone or download from [GitHub](https://github.com/raisov/resourceloader) to your directory, ResourceLoader.xcworkspace  will be found there. This workspace contains two Xcode projects:

* ResourceLoader - to build ResourceLoader.framework and run unit tests;
* LoaderDemo - to build and run an universal iOS application that demonstrates library usage.

The simplest way to integrate __ResourceLoader__ in your project is to include URLLoader.swift and CreatableFromData.swift files in a project source tree.
Another way is include whole ResourceLoader.xcodeproj in your workspace. Then open _Project Inspector_ and in _Build Phases_ tab add ResourceLoader.framework to _Link Binary With Libraries_ section. Don't forget `import ResourceLoader` and your are ready to use it.

## Demo Application

__LoaderDemo__ is an application that load and display randomly selected set of images  listed in [JSON](http://pastebin.com/raw/wgkJgazE). When a user press _Refresh_ button the next random images set loaded.
Application may run on iPhone or iPad with iOS version 11.0 and above.
`URLLoader` object is used in this application to load JSON with list of images URL and to asynchronously load this images, naturaly.

![Screen shot](./LoaderDemo/ScreenShot.png)

