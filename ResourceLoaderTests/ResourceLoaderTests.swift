//
//  ResourceLoaderTests.swift
//  ResourceLoaderTests
//
//  Created by bp on 2018-09-28.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import XCTest
import PDFKit
@testable import ResourceLoader

extension UIImage: CreatableFromData {}
extension XMLParser: CreatableFromData {}
extension PDFDocument: CreatableFromData {}

func archive(_ object: NSSecureCoding) -> Data {
    let archiver = NSKeyedArchiver()
    object.encode(with: archiver)
    archiver.finishEncoding()
    return archiver.encodedData
}

class ResourceLoaderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testJPG() {
        let loader = URLLoader<UIImage>(callbackQueue: DispatchQueue.global())
        let bundle = Bundle(for: type(of: self))

        let name = "orange"
        let ext = "jpg"

        let path = bundle.path(forResource: name, ofType: ext)!
        let url = bundle.url(forResource: name, withExtension: ext)!

        let image = UIImage(contentsOfFile: path)!
        let imageData = archive(image)

        let completion = DispatchSemaphore(value: 0)
        var requestId = ResourceQuery(id: 0, url: url)
        requestId = loader.requestResource(from: url, userData: imageData) {resource, id, userData in
            XCTAssertEqual(id, requestId)
            XCTAssertNotNil(userData as? Data)
            XCTAssertNotNil(resource, "can't load resource from " + url.relativeString)
            if let resource = resource, let userData = userData as? Data {
                XCTAssertEqual(resource.size, image.size)
                XCTAssertEqual(archive(resource), userData)
            }
            completion.signal()
        }
        completion.wait() // while completion handler has been finished
    }

    func testPNG() {
        let loader = URLLoader<UIImage>(callbackQueue: DispatchQueue.global())
        let bundle = Bundle(for: type(of: self))

        let name = "cherries"
        let ext = "png"

        let path = bundle.path(forResource: name, ofType: ext)!
        let url = bundle.url(forResource: name, withExtension: ext)!

        let image = UIImage(contentsOfFile: path)!
        let imageData = archive(image)

        let completion = DispatchSemaphore(value: 0)
        loader.requestResource(from: url) {resource, _, _ in
            XCTAssertNotNil(resource, "can't load resource from " + url.relativeString)
            if let resource = resource {
                XCTAssertEqual(resource.size, image.size)
                XCTAssertEqual(archive(resource), imageData)
            }

            completion.signal()
        }
        completion.wait() // while completion handler has been finished
    }

    func testXML() {

        class TestXMLParser: NSObject, XMLParserDelegate {
            var value = String()
            func parser(_ : XMLParser,
                        didStartElement elementName: String,
                        namespaceURI _: String?,
                        qualifiedName _: String?,
                        attributes _: [String : String]) {
                self.value.append(elementName)
            }

            func parser(_ : XMLParser,
                        didEndElement elementName: String,
                        namespaceURI _: String?,
                        qualifiedName _: String?) {
                self.value.append(elementName)
            }

            func parser(_ : XMLParser, foundCharacters: String) {
                self.value.append(foundCharacters)
            }
        }

        let loader = URLLoader<XMLParser>(callbackQueue: DispatchQueue.global())
        let bundle = Bundle(for: type(of: self))

        let name = "Info"
        let ext = "plist"

        let url = bundle.url(forResource: name, withExtension: ext)!
        let parser = XMLParser(contentsOf: url)!
        let parserDelegate = TestXMLParser()
        parser.delegate = parserDelegate
        parser.parse()
        let xmlContent = parserDelegate.value

        let completion = DispatchSemaphore(value: 0)
        loader.requestResource(from: url) {resource, _, _  in
            XCTAssertNotNil(resource, "can't load resource from " + url.relativeString)
            if let resource = resource {
                let parserDelegate = TestXMLParser()
                resource.delegate = parserDelegate
                resource.parse()
                XCTAssertEqual(parserDelegate.value, xmlContent)
            }
            completion.signal()
        }
        completion.wait() // while completion handler has been finished
    }

    func testPDF() {
        let loader = URLLoader<PDFDocument>(callbackQueue: DispatchQueue.global())
        let bundle = Bundle(for: type(of: self))

        let name = "cv"
        let ext = "pdf"

        let url = bundle.url(forResource: name, withExtension: ext)!

        let completion = DispatchSemaphore(value: 0)
        loader.requestResource(from: url) {resource, _, _  in
            XCTAssertNotNil(resource, "can't load resource from " + url.relativeString)
            if let resource = resource {
                let selections = resource.findString("Swift")
                XCTAssertFalse(selections.isEmpty, "Swift expirience not found in CV")
            }
            completion.signal()
        }
        completion.wait() // while completion handler has been finished
    }

    func testJSONObject() {
        let loader = URLLoader<JSONObject>(callbackQueue: DispatchQueue.global())
        let bundle = Bundle(for: type(of: self))

        let name = "JSONObject"
        let ext = "json"

        let url = bundle.url(forResource: name, withExtension: ext)!

        let completion = DispatchSemaphore(value: 0)
        loader.requestResource(from: url) {resource, _, _  in
            XCTAssertNotNil(resource, "can't load resource from " + url.relativeString)
            if let resource = resource {
                XCTAssertNotNil(resource.value["number"] as? Int)
                XCTAssertNotNil(resource.value["string"] as? String)
                XCTAssertNotNil(resource.value["bool"] as? Bool)
                XCTAssertNotNil(resource.value["empty"] as? NSNull)
            }
            completion.signal()
        }
        completion.wait() // while completion handler has been finished
    }

    func testJSONArray() {
        let loader = URLLoader<JSONArray>(callbackQueue: DispatchQueue.global())
        let bundle = Bundle(for: type(of: self))

        let name = "JSONArray"
        let ext = "json"

        let url = bundle.url(forResource: name, withExtension: ext)!

        let completion = DispatchSemaphore(value: 0)
        loader.requestResource(from: url) {resource, _, _  in
            XCTAssertNotNil(resource, "can't load resource from " + url.relativeString)
            if let resource = resource {
                XCTAssertEqual(resource.value.count, 12)
            }
            completion.signal()
        }
        completion.wait() // while completion handler has been finished
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
