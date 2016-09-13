//
//  ViewController.swift
//  VoiceRecognitionDemo
//
//  Created by Astemir Eleev on 21/08/16.
//  Copyright © 2016 Astemir Eleev. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var timeRemaining: UIProgressView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var microphoneButton: UIButton!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        microphoneButton.isEnabled = false
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }
    }
    
    @IBAction func microphoneTapped(_ sender: AnyObject) {
        if audioEngine.isRunning {
            stopRecording()
        } else {
            timer = Timer.scheduledTimer(timeInterval: 0.1,
                                         target: self,
                                         selector: #selector(ViewController.remainingTime),
                                         userInfo: nil,
                                         repeats: true)
            // Swift 2.2 and objc
            //            NSRunLoop.currentRunLoop().addTimer(self.timer!, forMode: NSRunLoopCommonModes)
            // Swift 2.3 and 3.0
            RunLoop.current.add(timer!, forMode: RunLoopMode.defaultRunLoopMode)
            
            startRecording()
            microphoneButton.setTitle("Stop Recording", for: .normal)
        }
    }
    
    func startRecording() {
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                
                self.textView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        textView.text = "Say something, I'm listening!"
        
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }
    
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        microphoneButton.isEnabled = false
        
        microphoneButton.setTitle("Start Recording", for: .normal)
    }
    
    // MARK: Timer

    
    func remainingTime() {
        print("progress: \(timeRemaining.progress)")
        timeRemaining.progress += 1.0  / 600.0
        
        if timeRemaining.progress >= 1.0 {
            stopRecording()
            timeRemaining.progress = 0.0
        }
        
    }
}
