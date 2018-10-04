//
//  ViewController.swift
//  LoaderDemo
//
//  Created by bp on 2018-09-29.
//  Copyright © 2018 bp. All rights reserved.
//

import UIKit
import ResourceLoader

extension ViewController: ImageLoaderDelegate {

    func update() {
        mumberOfElements = 10
        collectionView.reloadData()
        navigationItem.leftBarButtonItem?.isEnabled = true
    }

    func update(element: IndexPath) {
        collectionView.reloadItems(at: [element])
    }

}

class ViewController: UICollectionViewController {

    private var model: ImageLoader!

    @objc func refresh() {
        model.refresh()
    }

    @IBOutlet weak var redirectionSwitch: UISwitch!
    @IBAction func redirectionStatusChanged(_ sender: UISwitch) {
        model.redirection = sender.isOn
        model.refresh()
    }

    private var mumberOfElements = 0

    override func didReceiveMemoryWarning () {
        super.didReceiveMemoryWarning()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        model = ImageLoader(delegate: self)
        redirectionSwitch.setOn(model.redirection, animated: false)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        update()
     }

    /// Provides suitable cells size and equal cell spacing to different screen orientations.
    func makeLayout(for size: CGSize) {

        let maxItemSize = CGSize(width: 480, height: 320)

        func calc(available: CGFloat, maxSize: CGFloat, margins: CGFloat, spacing: CGFloat) -> (size: CGFloat, margin: CGFloat) {
            let n = CGFloat.maximum(2, (available - margins + spacing)/(maxSize + spacing)).rounded(.towardZero)
            let totalSpacing = (n - 1) * spacing
            let itemSize = ((available - margins - totalSpacing) / n).rounded(.towardZero)
            let required = n * itemSize + totalSpacing
            let actualMargin = (available - required) / 2
            return (size: itemSize, margin: actualMargin)
        }

        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        let inset = layout.sectionInset

        switch layout.scrollDirection {
        case .vertical:
            let (itemWidth, horizontalMargin) = calc( available: size.width,
                                        maxSize: maxItemSize.width,
                                        margins: inset.top + inset.bottom,
                                        spacing: layout.minimumInteritemSpacing)
            let itemHeight = ((maxItemSize.height * itemWidth) / maxItemSize.width).rounded(.towardZero)
            layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            layout.sectionInset = UIEdgeInsets(top: inset.top, left: horizontalMargin,
                                               bottom: inset.bottom, right: horizontalMargin)
        case .horizontal:
            let (itemHeight, verticalMargin) = calc( available: size.height,
                                        maxSize: maxItemSize.height,
                                        margins: inset.left + inset.right,
                                        spacing: layout.minimumLineSpacing)
            let itemWidth = ((maxItemSize.width * itemHeight) / maxItemSize.height).rounded(.towardZero)
            layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            layout.sectionInset = UIEdgeInsets(top: inset.top, left: verticalMargin,
                                               bottom: inset.bottom, right: verticalMargin)
        }

        layout.headerReferenceSize = CGSize(width: 0, height: 0)
        collectionView.collectionViewLayout = layout
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let bounds = collectionView.bounds
        makeLayout(for: CGSize(width: bounds.width, height: bounds.height))
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        makeLayout(for: size)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mumberOfElements
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PictureFrame", for: indexPath) as! PictureFrame
        let pendingView = cell.pendingView
        let imageView = cell.pictureView
        imageView?.alpha = 0

        let image = model.getImage(for: indexPath)
        imageView?.image = image
        if image == nil {
            pendingView?.startAnimating()
        } else {
            pendingView?.stopAnimating()
            UIView.animate(withDuration: 1.0) {
                imageView?.alpha = 1
            }
        }
        return cell
    }
}
