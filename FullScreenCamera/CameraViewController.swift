//
//  ViewController.swift
//  FullScreenCamera
//
//  Created by joonwon lee on 28/04/2019.
//  Copyright © 2019 com.joonwon. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController {
    // TODO: 초기 설정 1
    // - 필요한 요소들
    // - captureSession
    // - AVCaptureDeviceInput
    // - AVCapturePhotoOutput
    // - Queue: 비디오 관련 처리
    // - AVCaptureDevice DiscoverySession
    
    let captureSession = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput!
    let photoOutput = AVCapturePhotoOutput()
    
    let sessionQueue = DispatchQueue(label: "session Queue")
    let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    

    @IBOutlet weak var photoLibraryButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var blurBGView: UIVisualEffectView!
    @IBOutlet weak var switchButton: UIButton!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: 초기 설정 2
        previewView.session = captureSession
        sessionQueue.async {
            self.setupSession()
            self.startSession()
        }
        setupUI()
        
    }
    
    func setupUI() {
        photoLibraryButton.layer.cornerRadius = 10
        photoLibraryButton.layer.masksToBounds = true
        photoLibraryButton.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        photoLibraryButton.layer.borderWidth = 1
        
        captureButton.layer.cornerRadius = captureButton.bounds.height/2
        captureButton.layer.masksToBounds = true
        
        blurBGView.layer.cornerRadius = blurBGView.bounds.height/2
        blurBGView.layer.masksToBounds = true
    }
    
    
    @IBAction func switchCamera(sender: Any) {
        // TODO: 카메라는 1개 이상이어야함
        guard videoDeviceDiscoverySession.devices.count > 1 else { return }
        
        // TODO: 반대 카메라 찾아서 재설정
        // - 반대 카메라 찾기
        // - 새로운 디바이스를 가지고 세션 업데이트
        // - 카메라 토글 버튼 업데이트
        
        sessionQueue.async {
            // 현재 카메라 가져와서 위치 찾기
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            let isFront = currentPosition == .front
            let preferredPosition: AVCaptureDevice.Position = isFront ? .back : .front
            
            // 새로운 위치(방향)의 카메라를 찾기
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice?
            
            newVideoDevice = devices.first(where: { device in
                return preferredPosition == device.position
            })
            
            // update capture session
            if let newDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: newDevice)
                    self.captureSession.beginConfiguration()
                    self.captureSession.removeInput(self.videoDeviceInput)
                    
                    // add new device input
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                    } else {
                        self.captureSession.addInput(self.videoDeviceInput)
                    }
                    
                    self.captureSession.commitConfiguration()
                    
                    DispatchQueue.main.async {
                        self.updateSwitchCameraIcon(position: preferredPosition)
                    }
                } catch let error{
                    print("--> ERROR occured while creating device input: \(error.localizedDescription)")
                }
                
            }
        }
        
    }
    
    func updateSwitchCameraIcon(position: AVCaptureDevice.Position) {
        // TODO: Update ICON
        switch position {
        case .front:
            let image = #imageLiteral(resourceName: "ic_camera_front")
            switchButton.setImage(image, for: .normal)
        case .back:
            let image = #imageLiteral(resourceName: "ic_camera_rear")
            switchButton.setImage(image, for: .normal)
        default:
            break
        }
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        // TODO: photoOutput의 capturePhoto 메소드
        // orientation 맞추기
        // photooutput setting
        
        let videoPreviewLayerOrientation = self.previewView.videoPreviewLayer.connection?.videoOrientation
        sessionQueue.async {
            let connection = self.photoOutput.connection(with: .video)
            connection?.videoOrientation = videoPreviewLayerOrientation!
            
            let setting = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: setting, delegate: self)
        }
    }
    
    
    func savePhotoLibrary(image: UIImage) {
        // TODO: capture한 이미지 포토라이브러리에 저장
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                // 저장
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { (success, error) in
                    print("--> 이미지 저장 완료? \(success)")
                }
            } else {
                // 다시 요청
                print("--> 권한을 받지 못함")
            }
        }
    }
}


extension CameraViewController {
    // MARK: - Setup session and preview
    func setupSession() {
        // TODO: captureSession 구성하기
        // - presetSetting 하기
        // - beginConfiguration
        // - Add Video Input
        // - Add Photo Output
        // - commitConfiguration
        
        captureSession.sessionPreset = .photo
        captureSession.beginConfiguration()
        
        // Add Video Input
        guard let camera = videoDeviceDiscoverySession.devices.first else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                captureSession.commitConfiguration()
                return
            }
        } catch let error {
            print("--> ERROR: \(error.localizedDescription)")
            captureSession.commitConfiguration()
            return
        }
        
        // Add Photo Output
        photoOutput.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.commitConfiguration()
        
    }
    
    
    
    func startSession() {
        // TODO: session Start
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        // TODO: session Stop
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // TODO: capturePhoto delegate method 구현
        guard error == nil else { return }
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        
        self.savePhotoLibrary(image: image)
    }
}
