//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//
//  swiftlint:disable line_length

import AVFoundation
import UIKit

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
public final class ScannerViewController: UIViewController {
    /// Whether border detection is enabled
    var borderDetectionEnabled: Bool

    /// Whether flash is enabled
    var flashEnabled: Bool

    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewLayer = AVCaptureVideoPreviewLayer()

    /// The view that shows the focus rectangle (when the user taps to focus, similar to the Camera app)
    private var focusRectangle: FocusRectangleView!

    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()

    /// The original bar style that was set by the host app
    private var originalBarStyle: UIBarStyle?

    init(borderDetectionEnabled: Bool, flashEnabled: Bool) {
        self.borderDetectionEnabled = borderDetectionEnabled
        self.flashEnabled = flashEnabled
        super.init(nibName: nil, bundle: nil)
    }
  
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  
    private lazy var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.addCircularBackground()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add cancel icon
        let cancelImage = UIImage(systemName: "xmark", named: "cancel", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
        let cancelImageView = UIImageView(image: cancelImage)
        cancelImageView.contentMode = .center
        cancelImageView.tintColor = .black
        button.addSubview(cancelImageView)
        
        // Layout cancel icon
        cancelImageView.translatesAutoresizingMaskIntoConstraints = false
        let iconSize: CGFloat = 20.0
        NSLayoutConstraint.activate([
            cancelImageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            cancelImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            cancelImageView.widthAnchor.constraint(equalToConstant: iconSize),
            cancelImageView.heightAnchor.constraint(equalToConstant: iconSize)
        ])
        
        // Add action target
        button.addTarget(self, action: #selector(cancelImageScannerController), for: .touchUpInside)
        
        return button
    }()

    private lazy var autoScanButton: UIBarButtonItem = {
        let title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        let button = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(toggleAutoScan))
        button.tintColor = .white

        return button
    }()

    private lazy var flashButton: UIButton = {
        let button = UIButton()
        button.addCircularBackground()
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add flash icon
        let flashImage = UIImage(systemName: "bolt.slash.fill", named: "flashSlash", in: Bundle(for: ScannerViewController.self))
        let flashImageView = UIImageView(image: flashImage)
        flashImageView.contentMode = .center
        flashImageView.tintColor = .black
        flashImageView.tag = 01 // Required in order to change image when toggling flash 
        button.addSubview(flashImageView)
        
        // Layout flash icon
        flashImageView.translatesAutoresizingMaskIntoConstraints = false
        let iconSize: CGFloat = 20.0
        NSLayoutConstraint.activate([
            flashImageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            flashImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            flashImageView.widthAnchor.constraint(equalToConstant: iconSize),
            flashImageView.heightAnchor.constraint(equalToConstant: iconSize)
        ])
        
        // Check flash availability and set the alternate image if not available
        if !UIImagePickerController.isFlashAvailable(for: .rear) {
            flashImageView.tintColor = .lightGray
        }

        if let device = AVCaptureDevice.default(for: AVMediaType.video), device.torchMode == .on {
            let flashOffImage = UIImage(systemName: "bolt.fill", named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
            flashImageView.image = flashOffImage?.withRenderingMode(.alwaysTemplate)
        }
        
        // Add action target
        button.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .white)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    // MARK: - Life Cycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        title = nil
        view.backgroundColor = UIColor.black

        setupViews()
        setupConstraints()

        captureSessionManager = CaptureSessionManager(borderDetectionEnabled: borderDetectionEnabled, flashEnabled: flashEnabled, videoPreviewLayer: videoPreviewLayer, delegate: self)

        originalBarStyle = navigationController?.navigationBar.barStyle

        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: Notification.Name.AVCaptureDeviceSubjectAreaDidChange, object: nil)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()

        CaptureSession.current.isEditing = false
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true

        navigationController?.setNavigationBarHidden(true, animated: animated) 
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        videoPreviewLayer.frame = view.layer.bounds
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false

        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.barStyle = originalBarStyle ?? .default
        captureSessionManager?.stop()
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        if device.torchMode == .on {
            toggleFlash()
        }
    }

    // MARK: - Setups

    private func setupViews() {
        view.backgroundColor = .black
        view.layer.addSublayer(videoPreviewLayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        if (borderDetectionEnabled) { view.addSubview(quadView) }
        view.addSubview(flashButton)
        view.addSubview(cancelButton)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
    }

    private func setupConstraints() {
        var quadViewConstraints = [NSLayoutConstraint]()
        var flashButtonConstraints = [NSLayoutConstraint]()
        var cancelButtonConstraints = [NSLayoutConstraint]()
        var shutterButtonConstraints = [NSLayoutConstraint]()
        var activityIndicatorConstraints = [NSLayoutConstraint]()

        if (borderDetectionEnabled) {
            quadViewConstraints = [
                quadView.topAnchor.constraint(equalTo: view.topAnchor),
                view.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
                view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
                quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            ]
        }

        shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]

        activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]

        flashButtonConstraints = [
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            flashButton.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 18),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40)
        ]

        cancelButtonConstraints = [
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            cancelButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -18),
            cancelButton.widthAnchor.constraint(equalToConstant: 40),
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
        ]

        let shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 8.0)
        shutterButtonConstraints.append(shutterButtonBottomConstraint)

        NSLayoutConstraint.activate(quadViewConstraints + shutterButtonConstraints + flashButtonConstraints + cancelButtonConstraints  + activityIndicatorConstraints)
    }

    // MARK: - Tap to Focus

    /// Called when the AVCaptureDevice detects that the subject area has changed significantly. When it's called, we reset the focus so the camera is no longer out of focus.
    @objc private func subjectAreaDidChange() {
        /// Reset the focus and exposure back to automatic
        do {
            try CaptureSession.current.resetFocusToAuto()
        } catch {
            let error = ImageScannerControllerError.inputDevice
            guard let captureSessionManager else { return }
            captureSessionManager.delegate?.captureSessionManager(captureSessionManager, didFailWithError: error)
            return
        }

        /// Remove the focus rectangle if one exists
        CaptureSession.current.removeFocusRectangleIfNeeded(focusRectangle, animated: true)
    }

    // MARK: - Actions

    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }

    @objc private func toggleAutoScan() {
        if CaptureSession.current.isAutoScanEnabled {
            CaptureSession.current.isAutoScanEnabled = false
            autoScanButton.title = NSLocalizedString("wescan.scanning.manual", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Manual", comment: "The manual button state")
        } else {
            CaptureSession.current.isAutoScanEnabled = true
            autoScanButton.title = NSLocalizedString("wescan.scanning.auto", tableName: nil, bundle: Bundle(for: ScannerViewController.self), value: "Auto", comment: "The auto button state")
        }
    }

    @objc private func toggleFlash() {
        let state = CaptureSession.current.toggleFlash()

        if let flashImageView = flashButton.viewWithTag(01) as? UIImageView {
            let flashImage = UIImage(systemName: "bolt.fill", named: "flash", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)
            let flashOffImage = UIImage(systemName: "bolt.slash.fill", named: "flashUnavailable", in: Bundle(for: ScannerViewController.self), compatibleWith: nil)

            switch state {
            case .on:
                flashEnabled = true
                flashImageView.image = flashImage
                flashImageView.tintColor = .black
            case .off:
                flashEnabled = false
                flashImageView.image = flashOffImage
                flashImageView.tintColor = .black
            case .unknown, .unavailable:
                flashEnabled = false
                flashImageView.image = flashOffImage
                flashImageView.tintColor = .lightGray
            }
        }
    }

    @objc private func cancelImageScannerController() {
        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
    }
}

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {

        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true

        guard let imageScannerController = navigationController as? ImageScannerController else { return }
        imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
    }

    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        captureSessionManager.stop()
        shutterButton.isUserInteractionEnabled = false
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()

        guard let imageScannerController = navigationController as? ImageScannerController else { return }

        var croppedImage: UIImage?

        if let quad {
            guard let ciImage = CIImage(image: picture) else {
                let error = ImageScannerControllerError.ciImageCreation
                imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
                return
            }

            let cgOrientation = CGImagePropertyOrientation(picture.imageOrientation)
            let orientedImage = ciImage.oriented(forExifOrientation: Int32(cgOrientation.rawValue))
            let scaledQuad = quad.scale(picture.size, picture.size)

            var cartesianScaledQuad = scaledQuad.toCartesian(withHeight: picture.size.height)
            cartesianScaledQuad.reorganize()

            let filteredImage = orientedImage.applyingFilter("CIPerspectiveCorrection", parameters: [
                "inputTopLeft": CIVector(cgPoint: cartesianScaledQuad.bottomLeft),
                "inputTopRight": CIVector(cgPoint: cartesianScaledQuad.bottomRight),
                "inputBottomLeft": CIVector(cgPoint: cartesianScaledQuad.topLeft),
                "inputBottomRight": CIVector(cgPoint: cartesianScaledQuad.topRight)
            ])

            if borderDetectionEnabled {
                croppedImage = UIImage.from(ciImage: filteredImage)
            }
        }

        let results = ImageScannerResults(
          detectedRectangle: quad,
          originalScan: ImageScannerScan(image: picture),
          croppedScan: ImageScannerScan(image: croppedImage ?? picture),
          enhancedScan: ImageScannerScan(image: picture)
        )

        imageScannerController.imageScannerDelegate?
        .imageScannerController(imageScannerController, didFinishScanningWithResults: results)
    }

    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }

        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)

        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)

        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)

        let imageBounds = CGRect(origin: .zero, size: scaledImageSize).applying(rotationTransform)

        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)

        let transforms = [scaleTransform, rotationTransform, translationTransform]

        let transformedQuad = quad.applyTransforms(transforms)

        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
}
