import Foundation

public struct H264Unit {
    enum NALUType {
        case sps
        case pps
        case vcl
    }
    
    let type: NALUType
    
    private let payload: Data

    private var lengthData: Data?
    
    var data: Data {
        if type == .vcl {
            guard let lengthData = lengthData else { return payload }
            return lengthData + payload
        } else {
            return payload
        }
    }
    
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
