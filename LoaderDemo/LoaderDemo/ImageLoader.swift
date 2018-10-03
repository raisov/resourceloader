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
    func update(element: IndexPath)
}


class ImageLoader {

    weak var delegate: ImageLoaderDelegate? {
        didSet {
            loadTestData()
        }
    }

    private lazy var errorImage = UIImage(named: "troubles.png")

    private var urlList = [URL]()
    private var imagePool = [IndexPath : (url: URL, image: UIImage?)]()
    private var activeRequests = Set<RequestDescriptor>()

    private let imageLoader: URLLoader<UIImage>

    // In my homework were written: "Use the following URL to upload data"
    private let testURLString = "https://pastebin.com/raw/wgkJgazE"
    private var testURLList = [URL]()
    private var testURLLoadComplited = DispatchSemaphore(value: 0)
    private func loadTestData() {
        let jsonLoader = URLLoader<JSONArray>()
        let jsonURL = URL(string: testURLString)!
        jsonLoader.requestResource(from: jsonURL) {result, _, _ in
            switch result {
            case .success(let jsonItems):
                jsonItems.value.compactMap{$0 as? [String : Any]}.forEach {
                    guard let urls = $0["urls"] as? [String : String] else {return}
                    if let urlString = urls["raw"], let url = URL(string: urlString) {
                        self.urlList.append(url)
                    }
                }
                self.urlList.shuffle()
                self.delegate?.update()
            default:
                break
            }
        }
    }


    init() {
        imageLoader = URLLoader<UIImage>()
    }

    func refresh() {
            activeRequests.forEach{imageLoader.cancelRequest($0)}
            activeRequests.removeAll()
            imagePool.removeAll()
            urlList.shuffle()
            self.delegate?.update()
    }

    func getImage(for element: IndexPath) -> UIImage? {
        guard urlList.count != 0 else {return nil}
        var url: URL
        var image: UIImage?
        if let elementData = imagePool[element] {
            url = elementData.url
            image = elementData.image
        } else {
            url = urlList[imagePool.count % urlList.count]
            image = nil
            imagePool[element] = (url, image)
            let requestId = imageLoader.requestResource(from: url) {result, id, _ in
                self.activeRequests.remove(id)
                switch result {
                case .success(let image):
                    self.imagePool[element] = (url, image)
                default:
                    self.imagePool[element] = (url, self.errorImage)
                }
                self.delegate?.update(element: element)
            }
            activeRequests.insert(requestId)
        }
        return image
    }


}
