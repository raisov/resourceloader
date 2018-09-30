//
//  ImageLoader.swift
//  LoaderDemo
//
//  Created by bp on 2018-09-29.
//  Copyright © 2018 bp. All rights reserved.
//

import UIKit
import ResourceLoader

extension UIImage: CreatableFromData {}

protocol ImageLoaderDelegate: class {
    func update()
    func update(element: Int)
}


class ImageLoader {
    weak var delegate: ImageLoaderDelegate?

    private var urlList = [URL]()
    private var imagePool = [Int : (url: URL, image: UIImage?)]()
    private let imageLoader = URLLoader<UIImage>()
    private lazy var errorImage = UIImage(named: "troubles.png")

    // In my homework were written: "Use the following URL to upload data"
    private let testURLString = "https://pastebin.com/raw/wgkJgazE"
    private var testURLList = [URL]()
    private var testURLLoadComplited = DispatchSemaphore(value: 0)
    private func loadTestData() {
        print("Load Test Data")
        let jsonLoader = URLLoader<JSONArray>(callbackQueue: DispatchQueue.global())
        let jsonURL = URL(string: testURLString)!
        jsonLoader.requestResource(from: jsonURL) {jsonItems, _ in
            jsonItems?.value.compactMap{$0 as? [String : Any]}.forEach {
                guard let urls = $0["urls"] as? [String : String] else {return}
                if let urlString = urls["raw"], let url = URL(string: urlString) {
                    self.testURLList.append(url)
                }
            }
            self.testURLLoadComplited.signal()
        }
    }


    init() {
//        let url = Bundle.main.url(forResource: "test", withExtension: "jpg")!
//        urlList = [url]
        loadTestData()
    }

    var numberOfImages: Int {
        return urlList.count
    }

    func refresh() {
        imagePool.removeAll()
        let result = testURLLoadComplited.wait(timeout: DispatchTime.now() + .seconds(1))
        if result == .timedOut {print("T i m e o u t")}
        urlList = testURLList
        urlList.swapAt(0, 1)
        delegate?.update()
    }

    func getImage(for element: Int) -> UIImage? {
        guard urlList.count != 0 else {return nil}
        var url: URL
        var image: UIImage?
        print("element \(element)")
        if let elementData = imagePool[element] {
            url = elementData.url
            image = elementData.image
        } else {
            url = urlList[imagePool.count % urlList.count]
            image = nil
            imagePool[element] = (url, image)
            imageLoader.requestResource(from: url) {image, _ in
                self.imagePool[element] = (url, image ?? self.errorImage)
                self.delegate?.update(element: element)
           }
        }
        return image
    }


}
