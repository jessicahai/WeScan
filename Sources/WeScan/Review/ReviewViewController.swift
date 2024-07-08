//
//  ReviewViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/25/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit

/// The `ReviewViewController` offers an interface to review the image after it
/// has been cropped and deskewed according to the passed in quadrilateral.
final class ReviewViewController: UIViewController {

    private var rotationAngle = Measurement<UnitAngle>(value: 0, unit: .degrees)
    private var enhancedImageIsAvailable = false
    private var isCurrentlyDisplayingEnhancedImage = false

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        imageView.isOpaque = true
        imageView.image = results.croppedScan.image
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

//    private lazy var enhanceButton: UIBarButtonItem = {
//        let image = UIImage(
//            systemName: "wand.and.rays.inverse",
//            named: "enhance",
//            in: Bundle(for: ScannerViewController.self),
//            compatibleWith: nil
//        )
//        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toggleEnhancedImage))
//        button.tintColor = .white
//        return button
//    }()

    private lazy var rotateButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "rotate.right", named: "rotate", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(rotateImage), for: .touchUpInside)
        button.tintColor = .white
        return button
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "rotate.right", named: "rotate", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        button.tintColor = .white
        return button
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(systemName: "rotate.right", named: "rotate", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(finishScan), for: .touchUpInside)
        button.tintColor = .white
        return button
    }()



    private let results: ImageScannerResults

    // MARK: - Life Cycle

    init(results: ImageScannerResults) {
        self.results = results
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        enhancedImageIsAvailable = results.enhancedScan != nil

        setupViews()
        setupConstraints()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: animated) 
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    // MARK: Setups

    private func setupViews() {
        view.addSubview(imageView)
        view.addSubview(rotateButton)
        view.addSubview(backButton)
        view.addSubview(doneButton)
    }

    private func setupConstraints() {
        let imageViewConstraints = [
            view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.topAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.trailingAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.bottomAnchor),
            view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: imageView.safeAreaLayoutGuide.leadingAnchor)
        ]

        let rotateButtonConstraints = [
            rotateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rotateButton.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ]

        let backButtonConstraints = [
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            backButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 24),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ]

        let nextButtonConstraints = [
          doneButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
          doneButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -24),
          doneButton.widthAnchor.constraint(equalToConstant: 44),
          doneButton.heightAnchor.constraint(equalToConstant: 44)
        ]

        NSLayoutConstraint.activate(imageViewConstraints + rotateButtonConstraints + backButtonConstraints + nextButtonConstraints)
    }

    // MARK: - Actions

    @objc private func reloadImage() {
        if enhancedImageIsAvailable, isCurrentlyDisplayingEnhancedImage {
            imageView.image = results.enhancedScan?.image.rotated(by: rotationAngle) ?? results.enhancedScan?.image
        } else {
            imageView.image = results.croppedScan.image.rotated(by: rotationAngle) ?? results.croppedScan.image
        }
    }

    // @objc func toggleEnhancedImage() {
    //     guard enhancedImageIsAvailable else { return }

    //     isCurrentlyDisplayingEnhancedImage.toggle()
    //     reloadImage()

    //     if isCurrentlyDisplayingEnhancedImage {
    //         enhanceButton.tintColor = .yellow
    //     } else {
    //         enhanceButton.tintColor = .white
    //     }
    // }

    @objc func rotateImage() {
        rotationAngle.value += 90

        if rotationAngle.value == 360 {
            rotationAngle.value = 0
        }

        reloadImage()
    }

    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func finishScan() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }

        var newResults = results
        newResults.croppedScan.rotate(by: rotationAngle)
        newResults.enhancedScan?.rotate(by: rotationAngle)
        newResults.doesUserPreferEnhancedScan = isCurrentlyDisplayingEnhancedImage
        imageScannerController.imageScannerDelegate?
            .imageScannerController(imageScannerController, didFinishScanningWithResults: newResults)
    }

}
