import Foundation

/// Records all tap events for a session
public class TelemetryRecorder {
    private var events: [TapEvent] = []
    private let sessionID: String
    private let startTime: Date
    
    public init(sessionID: String) {
        self.sessionID = sessionID
        self.startTime = Date()
    }
    
    /// Record a tap event
    public func recordTap(row: Int, col: Int, action: TapAction) {
        let timestamp = Date().timeIntervalSince(startTime)
        let event = TapEvent(timestamp: timestamp, row: row, col: col, action: action)
        events.append(event)
    }
    
    /// Get all recorded events
    public func getEvents() -> [TapEvent] {
        return events
    }
    
    /// Clear all events
    public func clear() {
        events.removeAll()
    }
    
    /// Serialize events to JSON data
    public func serialize() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(events)
    }
    
    /// Save events to file
    public func saveToFile(_ filename: String) throws {
        let data = try serialize()
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("\(sessionID)-\(filename).json")
        try data.write(to: fileURL)
    }
    
    /// Load events from file
    public func loadFromFile(_ filename: String) throws {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("\(sessionID)-\(filename).json")
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        self.events = try decoder.decode([TapEvent].self, from: data)
    }
}
