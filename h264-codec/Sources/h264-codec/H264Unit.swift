//
//  H264Unit.swift
//  ScreenStreamerClient
//
//  Created by Victor Kachalov on 22.11.23.
//

import Foundation

public struct H264Unit {
    
    enum NALUType {
        case sps
        case pps
        case vcl
    }
    
    let type: NALUType
    
    private let payload: Data
    
    /// 4 bytes data represents NAL Unit's length
    private var lengthData: Data?
    
    /// it could be
    /// - pure NALU data(if SPS or PPS)
    /// - 4 bytes length data + NALU data(if not SPS or PPS)
    var data: Data {
        if type == .vcl {
            return lengthData! + payload
        } else {
            return payload
        }
    }
    
    /// - paramter payload: pure NALU data(no length data or start code)
    init(payload: Data) {
        let typeNumber = payload[0] & 0x1F
        
        if typeNumber == 7 {
            self.type = .sps
        } else if typeNumber == 8 {
            self.type = .pps
        } else {
            self.type = .vcl
            
            var naluLength = UInt32(payload.count)
            naluLength = CFSwapInt32HostToBig(naluLength)
            
            self.lengthData = Data(bytes: &naluLength, count: 4)
        }
        
        self.payload = payload
    }
}
