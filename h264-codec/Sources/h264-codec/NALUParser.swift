import Foundation

public final class NALUParser {
    private var dataStream = Data()
    
    private var searchIndex = 0
    
    private lazy var parsingQueue = DispatchQueue(
        label: "parsing.queue",
        qos: .userInteractive
    )

    public var h264UnitHandling: ((H264Unit) -> Void)?

    public init() {}

    public func enqueue(_ data: Data) {
        parsingQueue.async { [weak self] in
            guard let self else { return }
            dataStream.append(data)
            
            while searchIndex < dataStream.endIndex - 3 {
                if (dataStream[searchIndex]
                    | dataStream[searchIndex + 1]
                    | dataStream[searchIndex + 2]
                    | dataStream[searchIndex + 3]) == 1 {

                    if searchIndex != 0 {
                        let h264Unit = H264Unit(payload: dataStream[0..<searchIndex])
                        h264UnitHandling?(h264Unit)
                    }
                    
                    dataStream.removeSubrange(0 ... searchIndex + 3)
                    searchIndex = 0

                } else if dataStream[searchIndex + 3] != 0 {
                    searchIndex += 4
                } else {
                    searchIndex += 1
                }
            }
        }
    }
}
