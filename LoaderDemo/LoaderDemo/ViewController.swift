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
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
    }

    func update(element: Int) {
        guard let path = (collectionView.indexPathsForVisibleItems.first {$0.hashValue == element}) else {
            return
        }
        collectionView.reloadItems(at: [path])
    }

}

class ViewController: UICollectionViewController {

    private var model: ImageLoader!

    private var mumberOfElements = 0

    @objc func refresh() {
        navigationItem.rightBarButtonItem = nil
        model.refresh()
    }

    override func didReceiveMemoryWarning () {
        super.didReceiveMemoryWarning()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        model = ImageLoader()
        model.delegate = self
     }

    private func calculateLayout() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        let spacing = CGFloat(20)
        let margins = CGFloat(60)
        let maxCellSize = CGFloat(240)

        layout.headerReferenceSize = CGSize(width: 0, height: 0)
        let bounds = collectionView.bounds
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        let shortSide = CGFloat.minimum(bounds.width, bounds.height) - margins
        let itemsOnShortSide = CGFloat(2.0)
//        let itemsOnShortSide = CGFloat.maximum((shortSide/maxCellSize).rounded(.towardZero), 2.0)
        let shortSideTotalSpacing = spacing * (itemsOnShortSide - 1)
        let cellSize = ((shortSide - shortSideTotalSpacing) / itemsOnShortSide).rounded(.towardZero)
        layout.itemSize = CGSize(width: cellSize, height: cellSize)
        switch layout.scrollDirection {
        case .vertical:
            let itemsOnWidth = ((bounds.width + spacing - margins ) / (cellSize + spacing)).rounded(.towardZero)
            let totalWidthSpacing = spacing * (itemsOnWidth - 1)
            let widthInset = (bounds.width - cellSize * itemsOnWidth - totalWidthSpacing) / 2.0
            layout.sectionInset = UIEdgeInsets(top: margins / 2, left: widthInset,
                                               bottom: margins / 2, right: widthInset)
        case .horizontal:
            let itemsOnHeight = ((bounds.height + spacing - margins) / (cellSize + spacing)).rounded(.towardZero)
            let totalHeightSpacing = spacing * (itemsOnHeight - 1.0)
            let heightInset = (bounds.height - cellSize * itemsOnHeight - totalHeightSpacing) / 2.0
            layout.sectionInset = UIEdgeInsets(top: heightInset, left: margins / 2,
                                               bottom: heightInset, right: margins / 2)
        }
        collectionView.collectionViewLayout = layout
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        calculateLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        let itemSize = layout.itemSize
        let cellSize = itemSize.width
        let spacing = layout.minimumInteritemSpacing
        let inset = layout.sectionInset
        switch layout.scrollDirection {
        case .vertical:
            let margins = inset.top + inset.bottom
            let itemsOnWidth = ((size.width + spacing - margins ) / (cellSize + spacing)).rounded(.towardZero)
            let totalWidthSpacing = spacing * (itemsOnWidth - 1)
            let widthInset = (size.width - cellSize * itemsOnWidth - totalWidthSpacing) / 2.0
            layout.sectionInset = UIEdgeInsets(top: inset.top, left: widthInset,
                                               bottom: inset.bottom, right: widthInset)
        case .horizontal:
            let margins = inset.left + inset.right
            let itemsOnHeight = ((size.height + spacing - margins) / (cellSize + spacing)).rounded(.towardZero)
            let totalHeightSpacing = spacing * (itemsOnHeight - 1.0)
            let heightInset = (size.height - cellSize * itemsOnHeight - totalHeightSpacing) / 2.0
            layout.sectionInset = UIEdgeInsets(top: heightInset, left: inset.left,
                                               bottom: heightInset, right: inset.right)
        }
        collectionView.collectionViewLayout = layout
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mumberOfElements
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PictureFrame", for: indexPath) as! PictureFrame
        let pendingView = cell.pendingView
        let imageView = cell.pictureView
        imageView?.alpha = 0

        let image = model.getImage(for: indexPath.hashValue)
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
