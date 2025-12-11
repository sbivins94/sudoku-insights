import Foundation

/// Handles persistence of game sessions and reports
public class PersistenceService {
    private let fileManager = FileManager.default
    private lazy var documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    public init() {}
    
    /// Save a game session
    public func saveSession(_ session: GameSession) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)
        
        let filename = "\(session.id).json"
        let fileURL = documentsURL.appendingPathComponent("Sessions").appendingPathComponent(filename)
        
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }
    
    /// Load a game session
    public func loadSession(id: UUID) throws -> GameSession {
        let filename = "\(id).json"
        let fileURL = documentsURL.appendingPathComponent("Sessions").appendingPathComponent(filename)
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GameSession.self, from: data)
    }
    
    /// Save an analytics report
    public func saveReport(_ report: AnalyticsReport) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        
        let filename = "\(report.id).json"
        let fileURL = documentsURL.appendingPathComponent("Reports").appendingPathComponent(filename)
        
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }
    
    /// Load an analytics report
    public func loadReport(id: UUID) throws -> AnalyticsReport {
        let filename = "\(id).json"
        let fileURL = documentsURL.appendingPathComponent("Reports").appendingPathComponent(filename)
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AnalyticsReport.self, from: data)
    }
    
    /// List all saved sessions
    public func listSessions() throws -> [GameSession] {
        let sessionsURL = documentsURL.appendingPathComponent("Sessions")
        
        guard fileManager.fileExists(atPath: sessionsURL.path) else {
            return []
        }
        
        let files = try fileManager.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: nil)
        var sessions: [GameSession] = []
        
        for file in files where file.pathExtension == "json" {
            if let session = try? loadSession(id: UUID(uuidString: file.deletingPathExtension().lastPathComponent) ?? UUID()) {
                sessions.append(session)
            }
        }
        
        return sessions
    }
}
