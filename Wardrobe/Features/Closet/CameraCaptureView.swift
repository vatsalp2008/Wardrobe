import AVFoundation
import SwiftUI
import UIKit

/// Full-screen AVFoundation camera with a garment-framing guide (spec §5.1 / §7.3).
/// Manual capture button; auto-capture-when-framed is deferred (TRADEOFFS).
/// Camera is unavailable on the Simulator — callers should offer the Photos picker there.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        controller.onCancel = onCancel
        return controller
    }

    func updateUIViewController(_ controller: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "wardrobe.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        addFramingGuide()
        addControls()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { if !self.session.isRunning { self.session.startRunning() } }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func addFramingGuide() {
        let guide = UIView()
        guide.translatesAutoresizingMaskIntoConstraints = false
        guide.layer.borderColor = UIColor(red: 0.10, green: 0.34, blue: 0.63, alpha: 1).cgColor // brand blue
        guide.layer.borderWidth = 3
        guide.layer.cornerRadius = 16
        guide.backgroundColor = .clear
        view.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            guide.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            guide.heightAnchor.constraint(equalTo: guide.widthAnchor, multiplier: 1.3)
        ])

        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = "Center the garment in the frame"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 15, weight: .medium)
        hint.textAlignment = .center
        view.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.topAnchor.constraint(equalTo: guide.bottomAnchor, constant: 16)
        ])
    }

    private func addControls() {
        let capture = UIButton(type: .system)
        capture.translatesAutoresizingMaskIntoConstraints = false
        capture.backgroundColor = .white
        capture.layer.cornerRadius = 35
        capture.layer.borderWidth = 4
        capture.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        capture.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(capture)

        let cancel = UIButton(type: .system)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancel)

        NSLayoutConstraint.activate([
            capture.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            capture.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            capture.widthAnchor.constraint(equalToConstant: 70),
            capture.heightAnchor.constraint(equalToConstant: 70),
            cancel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cancel.centerYAnchor.constraint(equalTo: capture.centerYAnchor)
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.onCapture?(image) }
    }
}
