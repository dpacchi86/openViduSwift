//
//  OpenViduVideoVM.swift
//  WebRTCapp
//
//  Created by Dario Pacchi on 16/06/2020.
//  Copyright © 2020 Sergio Paniego Blanco. All rights reserved.
//

import Foundation
import WebRTC

class OpenViduVideoVM {
    
    var session = ""
    let username = "INSERT_USERNAME"
    let secret = "INSERT_SECRET"
    let baseUrl = "INSERT_URL"
        
    var partecipantName = ""
    
    var participants = [RemoteParticipant]()
    var socketService : WebSocketService?
    var peersService = PeersService()
    
    var localAudioTrack: RTCAudioTrack?
    var localVideoTrack: RTCVideoTrack?
    var videoSource: RTCVideoSource?
    var videoCapturer: RTCVideoCapturer?
    
    var isConnected = false
    var onUpdate : (()->())?
    var onSocket : ((Bool, String?)->())?
    
    var frontCameraActive = true
    var audioOn = true
    var videoOn = true
    
    private var mock = false
    
    deinit {
        print("OpenViduVideoVM deallocated")
    }
    
    //MARK: - Connect
    
    func connect() {
        connect(url: baseUrl, username: username, password: secret, session: session)
    }
    
    func connect(withUrl: String) {
        self.createSocket(url: withUrl)
        DispatchQueue.main.async {[weak self] in
            self?.onSocket?(true, nil)
            let mandatoryConstraints = ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"]
            let sdpConstraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
            self?.peersService.createLocalOffer(mediaConstraints: sdpConstraints);
        }
    }
    
    func connect(url: String, username: String, password: String, session: String) {
        
        OpenViduService.shared.connectTo(url: baseUrl, username: username, password: password, room: session) {[weak self] (token, success, error) in
            
            guard success == true, let token = token else {
                return
            }
            
            self?.createSocket(token: token, session: session)
            DispatchQueue.main.async {[weak self] in
                self?.onSocket?(true, nil)
                let mandatoryConstraints = ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"]
                let sdpConstraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
                self?.peersService.createLocalOffer(mediaConstraints: sdpConstraints);
            }
        }
    }
    
    //MARK: - Disconnect
    
    func disconnect() {
        socketService?.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {[weak self] in
            self?.peersService.webSocketListener = nil
            self?.socketService?.socket.disconnect()
        }
    }
    
    //MARK: - Create socket
    
    private func createSocket(token: OpenViduToken, session: String) {
        socketService = WebSocketService(baseUrl: token.token, sessionName: session, participantName: partecipantName, peersManager: self.peersService, openViduToken: token)
        peersService.webSocketListener = socketService
        peersService.start()
        addCallBacks()
    }
    
    private func createSocket(url: String) {
        
        socketService = WebSocketService(openViduURL: url, participantName: partecipantName, peersManager: peersService, basicAuthToken: OpenViduService.shared.basicTokenFor(username: username, password: secret))
        peersService.webSocketListener = socketService
        peersService.start()
        addCallBacks()
    }
    
    //MARK: - Add callbacks
    
    private func addCallBacks () {
        
        socketService?.onSocketConnected = {
            
        }
        
        socketService?.onSocketDisconnected = {[weak self] () in
            DispatchQueue.main.async {[weak self] in
                self?.onSocket?(false, nil)
            }
        }
        
        socketService?.onPartecipantsChanged = {[weak self] (participants) in
            self?.participants = participants.filter{$0.videoTrack != nil}
            DispatchQueue.main.async {[weak self] in
                self?.onUpdate?()
            }
        }
    }
    
    //MARK: - Create local stream sender
    
    func createMediaSenders() {
        
        let streamId = "stream"
        let stream = self.peersService.peerConnectionFactory!.mediaStream(withStreamId: streamId)
        
        // Audio
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = self.peersService.peerConnectionFactory!.audioSource(with: audioConstrains)
        let audioTrack = self.peersService.peerConnectionFactory!.audioTrack(with: audioSource, trackId: "audio0-ios")
        self.localAudioTrack = audioTrack
        self.peersService.localAudioTrack = audioTrack
        stream.addAudioTrack(audioTrack)
        
        // Video
        let videoSource = self.peersService.peerConnectionFactory!.videoSource()
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = self.peersService.peerConnectionFactory!.videoTrack(with: videoSource, trackId: "video0-ios")
        self.peersService.localVideoTrack = videoTrack
        self.localVideoTrack = videoTrack
        stream.addVideoTrack(videoTrack)
        
        self.peersService.localPeer!.add(stream)
        self.peersService.localPeer!.delegate = self.peersService
    }
    
    //MARK: - Toggle Video / Audio
    
    func toggleAudio() {
        guard let audioTrack = peersService.localPeer?.localStreams.first?.audioTracks.first else {
            return
        }
        audioOn = !audioOn
        audioTrack.isEnabled = !audioTrack.isEnabled
        
    }
    
    func toggleVideo() {
        
        guard let videoTrack = peersService.localPeer?.localStreams.first?.videoTracks.first else {
            return
        }
        videoOn = !videoOn
        videoTrack.isEnabled = !videoTrack.isEnabled
    }
}
