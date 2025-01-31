/*
 * Copyright (C) 2016 nohana, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an &quot;AS IS&quot; BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import Photos

final class MomentViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, ActivityIndicatable {

    weak var nohanaImagePickerController: NohanaImagePickerController?
    var photoKitAssetList: PhotoKitAssetList!
    var momentInfoSectionList: [MomentInfoSection] = []
    var isFirstAppearance = true
    
    var cellSize: CGSize {
        guard let nohanaImagePickerController = nohanaImagePickerController else {
            return CGSize.zero
        }
        var numberOfColumns = nohanaImagePickerController.numberOfColumnsInLandscape
        if UIApplication.shared.statusBarOrientation.isPortrait {
            numberOfColumns = nohanaImagePickerController.numberOfColumnsInPortrait
        }
        let cellMargin: CGFloat = 2
        let cellWidth = (view.frame.width - cellMargin * (CGFloat(numberOfColumns) - 1)) / CGFloat(numberOfColumns)
        return CGSize(width: cellWidth, height: cellWidth)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = nohanaImagePickerController?.config.color.background ?? .white
        updateTitle()
        setUpToolbarItems()
        addPickPhotoKitAssetNotificationObservers()
        setUpActivityIndicator()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let mediaType = self.nohanaImagePickerController?.mediaType else { return }
            self.momentInfoSectionList = MomentInfoSectionCreater().createSections(mediaType: mediaType)
            self.isLoading = false
            self.collectionView?.reloadData()
            self.isFirstAppearance = true
            self.scrollCollectionViewToInitialPosition()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let nohanaImagePickerController = nohanaImagePickerController {
            setToolbarTitle(nohanaImagePickerController)
        }
        collectionView?.reloadData()
        scrollCollectionViewToInitialPosition()
    }

    func updateTitle() {
        if let nohanaImagePickerController = nohanaImagePickerController {
            title = NSLocalizedString("albumlist.moment.title", tableName: "NohanaImagePicker", bundle: nohanaImagePickerController.assetBundle, comment: "")
        }
    }

    func scrollCollectionView(to indexPath: IndexPath) {
        let count: Int? = momentInfoSectionList.count
        guard count != nil && count! > 0 else {
            return
        }
        DispatchQueue.main.async {
            self.collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: false)
        }
    }

    func scrollCollectionViewToInitialPosition() {
        guard isFirstAppearance else {
            return
        }
        let lastSection = momentInfoSectionList.count - 1
        guard lastSection >= 0 else {
            return
        }
        let indexPath = IndexPath(item: momentInfoSectionList[lastSection].assetResult.count - 1, section: lastSection)
        scrollCollectionView(to: indexPath)
        isFirstAppearance = false
    }

    // MARK: - UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        if let activityIndicator = activityIndicator {
            updateVisibilityOfActivityIndicator(activityIndicator)
        }

        return momentInfoSectionList.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return momentInfoSectionList[section].assetResult.count
    }

    // MARK: - UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AssetCell", for: indexPath) as? AssetCell,
            let nohanaImagePickerController = nohanaImagePickerController else {
                fatalError("failed to dequeueReusableCellWithIdentifier(\"AssetCell\")")
        }

        let asset = PhotoKitAsset(asset: momentInfoSectionList[indexPath.section].assetResult[indexPath.row])
        cell.tag = indexPath.item
        cell.update(asset: asset, nohanaImagePickerController: nohanaImagePickerController)

        let imageSize = CGSize(
            width: cellSize.width * UIScreen.main.scale,
            height: cellSize.height * UIScreen.main.scale
        )
        asset.image(targetSize: imageSize) { (imageData) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in
                if let imageData = imageData {
                    if cell.tag == indexPath.item {
                        cell.imageView.image = imageData.image
                    }
                }
            })
        }
        return (nohanaImagePickerController.delegate?.nohanaImagePicker?(nohanaImagePickerController, assetListViewController: self, cell: cell, indexPath: indexPath, photoKitAsset: asset.originalAsset)) ?? cell
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let album = momentInfoSectionList[indexPath.section]
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "MomentHeader", for: indexPath) as? MomentSectionHeaderView else {
                fatalError("failed to create MomentHeader")
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = DateFormatter.Style.none
            header.dateLabel.text = formatter.string(from: album.creationDate)
            return header
        default:
            fatalError("failed to create MomentHeader")
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }

    // MARK: - ActivityIndicatable

    var activityIndicator: UIActivityIndicatorView?
    var isLoading = true

    func setUpActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .gray)
        let screenRect = Size.screenRectWithoutAppBar(self)
        activityIndicator?.center = CGPoint(x: screenRect.size.width / 2, y: screenRect.size.height / 2)
        activityIndicator?.startAnimating()
    }

    func isProgressing() -> Bool {
        return isLoading
    }

    // MARK: - UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let nohanaImagePickerController = nohanaImagePickerController {
            nohanaImagePickerController.delegate?.nohanaImagePicker?(nohanaImagePickerController, didSelectPhotoKitAsset: momentInfoSectionList[indexPath.section].assetResult[indexPath.row])
        }
    }

    // MARK: - Storyboard

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let selectedIndexPath = collectionView?.indexPathsForSelectedItems?.first else {
            return
        }
        let momentDetailListViewController = segue.destination as! MomentDetailListViewController
        momentDetailListViewController.momentInfoSection = momentInfoSectionList[selectedIndexPath.section]
        momentDetailListViewController.nohanaImagePickerController = nohanaImagePickerController
        momentDetailListViewController.currentIndexPath = selectedIndexPath
    }

    // MARK: - IBAction

    @IBAction func didPushDone(_ sender: AnyObject) {
        if let nohanaImagePickerController = nohanaImagePickerController {
            let pickedPhotoKitAssets = nohanaImagePickerController.pickedAssetList.map { ($0 as! PhotoKitAsset).originalAsset }
            nohanaImagePickerController.delegate?.nohanaImagePicker(nohanaImagePickerController, didFinishPickingPhotoKitAssets: pickedPhotoKitAssets)
        }
    }
}
