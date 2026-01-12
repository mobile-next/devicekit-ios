import Foundation

/// A lightweight wrapper representing a single H.264 NAL unit.
///
/// `H264Unit` inspects the raw NALU payload, determines its type (SPS, PPS, or VCL),
/// and optionally prepends a 4‑byte big‑endian length field for VCL units.
///
/// This struct is useful when converting between:
/// - **AVCC format** (length‑prefixed NAL units)
/// - **Annex‑B format** (start‑code prefixed)
///
/// ## Important Notes
/// - SPS (type 7) and PPS (type 8) are returned **as‑is**.
/// - VCL units (all other types) are returned **with a 4‑byte length prefix**.
/// - The struct does **not** add Annex‑B start codes (`0x00000001`).
/// - `lengthData` is force‑unwrapped in `data`, so malformed payloads can crash.
/// - No validation is performed on the payload length or NALU header.
public struct H264Unit {
    
    /// High‑level classification of H.264 NAL units.
    ///
    /// - `sps`: Sequence Parameter Set (type 7)
    /// - `pps`: Picture Parameter Set (type 8)
    /// - `vcl`: Video Coding Layer (all other types)
    enum NALUType {
        case sps
        case pps
        case vcl
    }
    
    /// The detected NALU type based on the first byte of the payload.
    let type: NALUType
    
    /// The raw NALU payload (excluding any length prefix).
    private let payload: Data
    
    /// A 4‑byte big‑endian length prefix for VCL units.
    ///
    /// SPS and PPS do not use this field.
    private var lengthData: Data?
    
    /// Returns the encoded NAL unit in AVCC format.
    ///
    /// - For `.vcl`: `[4‑byte length] + payload`
    /// - For `.sps` / `.pps`: `payload`
    ///
    /// ## Potential Issue
    /// - `lengthData!` is force‑unwrapped and will crash if `type == .vcl`
    ///   but `lengthData` was not initialized correctly.
    var data: Data {
        if type == .vcl {
            return lengthData! + payload
        } else {
            return payload
        }
    }
    
    /// Creates an `H264Unit` by inspecting the NALU header.
    ///
    /// - Parameter payload: The raw NALU bytes, beginning with the NALU header.
    ///
    /// ## Behavior
    /// - Extracts the NALU type from the lower 5 bits of the first byte.
    /// - Classifies type 7 as SPS, type 8 as PPS, everything else as VCL.
    /// - For VCL units, computes a 4‑byte big‑endian length prefix.
    ///
    /// ## Potential Issues
    /// - No validation that `payload` is non‑empty.
    /// - No handling for SEI, AUD, or other non‑VCL NALU types.
    /// - Length prefix uses the **entire payload size**, which is correct for AVCC
    ///   but may not match expectations for Annex‑B workflows.
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
