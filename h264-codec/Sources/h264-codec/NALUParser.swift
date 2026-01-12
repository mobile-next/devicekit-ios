import Foundation

/// A streaming parser that extracts H.264 NAL units from an incoming byte stream.
///
/// `NALUParser` consumes arbitrary chunks of data (such as from a socket or file),
/// searches for **Annex‑B start codes** (`0x00 00 00 01`), and emits each complete
/// NAL unit via the `h264UnitHandling` callback.
///
/// The parser is designed for continuous, incremental input: you call `enqueue(_:)`
/// with new data, and the parser maintains internal state until it finds the next
/// start code.
///
/// ## Important Notes
/// - The parser uses a **bitwise OR** heuristic to detect the start code, which is
///   not a strict comparison and may produce false positives.
/// - The parser assumes **4‑byte start codes only**; 3‑byte start codes (`00 00 01`)
///   are not supported.
/// - `searchIndex` is not reset when new data is appended, except when a start code
///   is found.
/// - `unowned self` inside the async block will crash if the parser is deallocated
///   while parsing is still in progress.
/// - The parser does not validate NALU boundaries or payload correctness.
/// - The parser removes consumed bytes from `dataStream`, which is efficient but
///   may cause frequent reallocations for large streams.
public final class NALUParser {

    /// Internal buffer holding unparsed data.
    private var dataStream = Data()
    
    /// Current scanning index within `dataStream`.
    private var searchIndex = 0
    
    /// Queue used for parsing to avoid blocking the caller.
    private lazy var parsingQueue = DispatchQueue(
        label: "parsing.queue",
        qos: .userInteractive
    )

    /// Callback invoked whenever a complete NAL unit is extracted.
    ///
    /// The callback receives an `H264Unit`, which classifies the NALU and provides
    /// its payload in AVCC format (length‑prefixed for VCL units).
    public var h264UnitHandling: ((H264Unit) -> Void)?

    /// Creates a new streaming NALU parser.
    public init() {}

    /// Enqueues new data for parsing.
    ///
    /// - Parameter data: Arbitrary bytes that may contain zero, one, or multiple NAL units.
    ///
    /// This method:
    /// - Appends the new data to the internal buffer.
    /// - Scans for the next Annex‑B start code (`00 00 00 01`).
    /// - When found:
    ///   - Emits the preceding bytes as a complete NAL unit (if non‑empty).
    ///   - Removes the consumed bytes from the buffer.
    ///   - Resets `searchIndex` to 0.
    ///
    /// ## Start Code Detection Logic
    /// The parser checks:
    ///
    /// ```swift
    /// (byte0 | byte1 | byte2 | byte3) == 1
    /// ```
    ///
    /// This is **not** a strict equality check against `00 00 00 01`.
    /// It will match any sequence where the OR of the four bytes equals `1`,
    /// which can produce false positives.
    ///
    /// ## Potential Issues
    /// - False positives due to OR‑based detection.
    /// - No support for 3‑byte start codes.
    /// - If the parser is deallocated while parsing is in progress, `unowned self`
    ///   will cause a crash.
    /// - Removing subranges from the front of `Data` may cause repeated copying.
    public func enqueue(_ data: Data) {
        parsingQueue.async { [unowned self] in
            dataStream.append(data)
            
            while searchIndex < dataStream.endIndex - 3 {

                // Heuristic start‑code detection (00 00 00 01)
                if (dataStream[searchIndex]
                    | dataStream[searchIndex + 1]
                    | dataStream[searchIndex + 2]
                    | dataStream[searchIndex + 3]) == 1 {

                    // Emit the NALU preceding the start code
                    if searchIndex != 0 {
                        let h264Unit = H264Unit(payload: dataStream[0..<searchIndex])
                        h264UnitHandling?(h264Unit)
                    }
                    
                    // Remove the start code and preceding bytes
                    dataStream.removeSubrange(0 ... searchIndex + 3)
                    searchIndex = 0

                } else if dataStream[searchIndex + 3] != 0 {
                    // Skip ahead when the 4th byte is non‑zero
                    searchIndex += 4

                } else {
                    // Otherwise advance one byte
                    searchIndex += 1
                }
            }
        }
    }
}
