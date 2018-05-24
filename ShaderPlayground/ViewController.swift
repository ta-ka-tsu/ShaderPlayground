//
//  ViewController.swift
//  ShaderPlayground
//
//  Created by TakatsuYouichi on 2018/04/15.
//  Copyright © 2018年 TakatsuYouichi. All rights reserved.
//

import UIKit
import Metal
import MetalKit
import AVFoundation
import CoreMotion

typealias Acceleration = float3

class ViewController: UIViewController {
    
    @IBOutlet weak var metalView: MTKView!
    
    var device:MTLDevice! = nil
    var commandQueue : MTLCommandQueue! = nil
    var pipelineState : MTLRenderPipelineState! = nil

    var defaultLibrary : MTLLibrary! = nil
    var compiledLibrary : MTLLibrary! = nil
    
    var vertexBuffer : MTLBuffer! = nil
    var resolutionBuffer : MTLBuffer! = nil
    var timeBuffer : MTLBuffer! = nil
    var volumeBuffer : MTLBuffer! = nil
    var accelerationBuffer : MTLBuffer! = nil
    
    let useDefaultLibrary = false
    let startDate = Date()
    
    var volumeLevel : Float = 0.0
    var acceleration = Acceleration(x:0.0, y:0.0, z:0.0)
    var motionManager = CMMotionManager()
    
    private let captureSession = AVCaptureSession()
    private let serialQueue = DispatchQueue(label: "Audio")
    
    func setUpPipeline() {
        // Library
        defaultLibrary = device.makeDefaultLibrary()
        
        let library : MTLLibrary = (useDefaultLibrary) ? defaultLibrary : compiledLibrary

        // RenderingPipeline
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        }
        catch let error {
            print("Failed to make RenderingPipeline. error : \(error)")
        }
    }
    
    func setUpVertexBuffer() {
        let vertexData : [Float] = [
            -1.0, -1.0,
            1.0, -1.0,
            -1.0, 1.0,
            1.0, 1.0
        ]
        
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
    }
    
    func setUpUniformBuffers() {
        resolutionBuffer = device.makeBuffer(length: 2 * MemoryLayout<Float>.size, options: [])
        timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        volumeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        accelerationBuffer = device.makeBuffer(length: MemoryLayout<Acceleration>.size, options: [])
    }
    
    func setUpAudioInput() {
        let audioDevice = AVCaptureDevice.default(for: .audio)!
        let audioInput = try! AVCaptureDeviceInput(device: audioDevice)
        let audioOut = AVCaptureAudioDataOutput()
        audioOut.setSampleBufferDelegate(self, queue: serialQueue)
        
        captureSession.addInput(audioInput)
        captureSession.addOutput(audioOut)
        
        captureSession.startRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Device
        device = MTLCreateSystemDefaultDevice()
        
        // View MTKViewを使っているのでPixelFormatやレイヤーの設定などはいらない
        metalView.device = device
        metalView.delegate = self
        
        // パイプライン
        self.setUpPipeline()
        
        // バッファ
        self.setUpVertexBuffer()
        self.setUpUniformBuffers()
        
        // コマンドキュー
        commandQueue = device.makeCommandQueue()
        
        // マイク入力
        self.setUpAudioInput()
        
        // 加速度センサー
        self.motionManager.accelerometerUpdateInterval = 1.0/60.0
        self.motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak `self`](motion, error) in
            guard let motion = motion, let `self` = self else { return }
            self.acceleration.x = Float(motion.gravity.x)
            self.acceleration.y = Float(motion.gravity.y)
            self.acceleration.z = Float(motion.gravity.z)
            memcpy(self.accelerationBuffer.contents(), &self.acceleration, MemoryLayout<Acceleration>.size)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onTapGesture(_ sender: UITapGestureRecognizer) {
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }
}

extension ViewController : MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let resolution = [Float(size.width), Float(size.height)]
        memcpy(resolutionBuffer.contents(), resolution, MemoryLayout<Float>.size * 2)
    }
    
    func draw(in view: MTKView) {
        guard
            let renderPassDesicriptor = metalView.currentRenderPassDescriptor,
            let currentDrawable = metalView.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer() else {
                return
        }
        
        let pTimeData = timeBuffer.contents()
        let vTimeData = pTimeData.bindMemory(to: Float.self, capacity: 1)
        vTimeData[0] = Float(Date().timeIntervalSince(startDate))
        
        let pVolumeData = volumeBuffer.contents()
        let vVolumeData = pVolumeData.bindMemory(to: Float.self, capacity: 1)
        vVolumeData[0] = volumeLevel
        
        let pData = accelerationBuffer.contents()
        let vData = pData.bindMemory(to: Acceleration.self, capacity: 1)
        vData[0] = acceleration

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesicriptor)
        renderEncoder?.label = "render command"
        
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        renderEncoder?.setFragmentBuffer(resolutionBuffer, offset: 0, index: 0)
        renderEncoder?.setFragmentBuffer(timeBuffer, offset: 0, index: 1)
        renderEncoder?.setFragmentBuffer(volumeBuffer, offset: 0, index: 2)
        renderEncoder?.setFragmentBuffer(accelerationBuffer, offset: 0, index: 3)
        
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder?.endEncoding()
        
        // commit
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}

extension ViewController : AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let channel = connection.audioChannels.first else {
            return
        }
        volumeLevel = exp(channel.averagePowerLevel/20.0)
    }
}

