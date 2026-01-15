import Foundation
import Combine
import Vapor
import NIOFoundationCompat

/// HTTP server for MCP protocol using Vapor.
@MainActor
final class MCPServer: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRunning = false
    @Published private(set) var port: Int = 3000
    @Published private(set) var lastError: String?

    // MARK: - Private Properties

    private var app: Application?
    private let router = MCPRouter.shared

    // MARK: - Singleton

    static let shared = MCPServer()

    private init() {}

    // MARK: - Server Lifecycle

    /// Start the HTTP server on the specified port.
    /// - Parameter port: Port number to listen on (default: 3000)
    func start(port: Int = 3000) async throws {
        guard !isRunning else { return }

        self.port = port
        lastError = nil

        do {
            // Create Vapor application
            var env = try Environment.detect()
            env.arguments = ["vapor"]  // Suppress command line parsing

            let app = try await Application.make(env)
            self.app = app

            // Configure to bind only to localhost for security
            app.http.server.configuration.hostname = "127.0.0.1"
            app.http.server.configuration.port = port

            // Disable Vapor's default logging for cleaner output
            app.logger.logLevel = .warning

            // Configure routes
            configureRoutes(app)

            // Start server in background
            try await app.startup()

            isRunning = true
            print("MCP Server started on http://localhost:\(port)")

        } catch {
            lastError = error.localizedDescription
            throw OutlinerError.serverStartFailed(port: port, detail: error.localizedDescription)
        }
    }

    /// Stop the HTTP server.
    func stop() async {
        guard isRunning, let app = app else { return }

        self.app = nil
        isRunning = false

        // Shutdown Vapor on a background thread to avoid async context issues
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                app.shutdown()
                continuation.resume()
            }
        }

        // Wait for shutdown to fully complete
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        print("MCP Server stopped")
    }

    /// Restart the server with a new port.
    func restart(port: Int) async throws {
        await stop()
        try await start(port: port)
    }

    // MARK: - Route Configuration

    private func configureRoutes(_ app: Application) {
        // Health check endpoint
        app.get("health") { req -> String in
            return "OK"
        }

        // MCP endpoint - handles all MCP protocol messages
        app.on(.POST, "mcp") { [weak self] req async -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }

            // Get request body
            guard let body = req.body.data else {
                return Response(status: .badRequest)
            }

            let data = Data(buffer: body)

            // Route to MCP handler
            let responseData = await self.router.handleRequest(data: data)

            // Return response
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            return Response(
                status: .ok,
                headers: headers,
                body: .init(data: responseData)
            )
        }

        // Also support POST to root for compatibility
        app.on(.POST, "") { [weak self] req async -> Response in
            guard let self = self else {
                return Response(status: .internalServerError)
            }

            guard let body = req.body.data else {
                return Response(status: .badRequest)
            }

            let data = Data(buffer: body)
            let responseData = await self.router.handleRequest(data: data)

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            return Response(
                status: .ok,
                headers: headers,
                body: .init(data: responseData)
            )
        }

        // Server info endpoint for discovery
        app.get("") { req -> Response in
            let info: [String: Any] = [
                "name": MCPServerInfo.current.name,
                "version": MCPServerInfo.current.version,
                "protocol": "mcp",
                "transport": "http"
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: info, options: .prettyPrinted) else {
                return Response(status: .internalServerError)
            }

            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/json")

            return Response(
                status: .ok,
                headers: headers,
                body: .init(data: data)
            )
        }

        // CORS preflight handling - restricted to localhost origins only for security
        app.on(.OPTIONS, "mcp") { req -> Response in
            var headers = HTTPHeaders()

            // Only allow CORS from localhost origins to prevent cross-origin attacks
            if let origin = req.headers.first(name: .origin),
               Self.isLocalhostOrigin(origin) {
                headers.add(name: .accessControlAllowOrigin, value: origin)
                headers.add(name: .accessControlAllowMethods, value: "POST, OPTIONS")
                headers.add(name: .accessControlAllowHeaders, value: "Content-Type")
            }

            return Response(status: .ok, headers: headers)
        }
    }

    // MARK: - CORS Helpers

    /// Check if an origin is a localhost origin (security measure).
    private nonisolated static func isLocalhostOrigin(_ origin: String) -> Bool {
        guard let url = URL(string: origin),
              let host = url.host?.lowercased() else {
            return false
        }

        // Allow localhost, 127.0.0.1, and IPv6 localhost
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    // MARK: - Server URL

    /// Get the server URL for configuration.
    var serverURL: String {
        "http://localhost:\(port)"
    }

    /// Get the MCP endpoint URL.
    var mcpEndpoint: String {
        "http://localhost:\(port)/mcp"
    }
}

// MARK: - Vapor Extensions

extension Application {
    /// Async-friendly startup.
    func startup() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try self.start()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Async-friendly shutdown.
    func asyncShutdown() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.shutdown()
            continuation.resume()
        }
    }
}
