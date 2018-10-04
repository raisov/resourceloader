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

    private unowned let delegate: ImageLoaderDelegate

    private lazy var errorImage = UIImage(named: "troubles.png")

    private var imagePool = [IndexPath : (url: URL, image: UIImage?)]()
    
    private let imageLoader: URLLoader<UIImage>

    init(delegate: ImageLoaderDelegate) {
        self.delegate = delegate
        imageLoader = URLLoader<UIImage>()
    }

    var redirection = true

    func refresh() {
            imagePool.removeAll()
            self.delegate.update()
    }

    func getImage(for element: IndexPath) -> UIImage? {
        var url: URL
        var image: UIImage?
        if let elementData = imagePool[element] {
            url = elementData.url
            image = elementData.image
        } else {
            url = URL(string: "https://picsum.photos/480/320" +
                (redirection ? "?random" : ""))!
            image = nil
            imagePool[element] = (url, image)
            imageLoader.requestResource(from: url) {result, _ in
                switch result {
                case .success(let image):
                    self.imagePool[element] = (url, image)
                default:
                    self.imagePool[element] = (url, self.errorImage)
                }
                self.delegate.update(element: element)
            }
        }
        return image
    }


}
