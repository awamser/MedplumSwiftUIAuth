import SwiftUI
import AuthenticationServices
import CryptoKit

class AuthViewModel: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var error: String?

    private var codeVerifier: String?
    private var codeChallenge: String?

    private struct AuthConfig {
        static let baseUrl = "https://api.medplum.com"
        static let authorizeEndpoint = "/oauth2/authorize"
        static let tokenEndpoint = "/oauth2/token"
        static let responseType = "code"
        static let redirectUri = "medplum-oauth://redirect"
        static let scope = "openid"
        static let codeChallengeMethod = "S256"
    }

    enum AuthError: Error, LocalizedError {
        case invalidURLComponents
        case authenticationFailed(String)
        case authorizationCodeParsingFailed
        case networkError(String)
        case tokenExchangeFailed(String)
        case unknownError

        var errorDescription: String? {
            switch self {
                case .invalidURLComponents:
                    return "Invalid URL components"
                case .authenticationFailed(let message):
                    return "Authentication failed: \(message)"
                case .authorizationCodeParsingFailed:
                    return "Failed to parse authorization code from callback URL"
                case .networkError(let message):
                    return "Network error: \(message)"
                case .tokenExchangeFailed(let message):
                    return "Token exchange failed: \(message)"
                case .unknownError:
                    return "An unknown error occurred"
            }
        }
    }

    func login() {
        generateCodeVerifier()

        guard let authUrl = createAuthURL() else {
            handleError(.invalidURLComponents)
            return
        }

        let scheme = URL(string: AuthConfig.redirectUri)!.scheme

        startAuthSession(authUrl: authUrl, scheme: scheme)
    }

    private func startAuthSession(authUrl: URL, scheme: String?) {
        let session = ASWebAuthenticationSession(url: authUrl, callbackURLScheme: scheme) { callbackURL, error in
            if let error = error {
                self.handleError(.authenticationFailed(error.localizedDescription))
                return
            }

            guard let callbackURL = callbackURL, let code = self.handleCallback(callbackURL) else {
                self.handleError(.authorizationCodeParsingFailed)
                return
            }

            self.exchangeCodeForToken(code)
        }

        session.presentationContextProvider = self
        session.start()
    }

    private func createAuthURL() -> URL? {
        var components = URLComponents(string: "\(AuthConfig.baseUrl)\(AuthConfig.authorizeEndpoint)")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value:  loadClientId()),
            URLQueryItem(name: "response_type", value: AuthConfig.responseType),
            URLQueryItem(name: "redirect_uri", value: AuthConfig.redirectUri),
            URLQueryItem(name: "scope", value: AuthConfig.scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: AuthConfig.codeChallengeMethod)
        ]
        return components?.url
    }


    private func handleCallback(_ url: URL) -> String? {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return urlComponents.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func exchangeCodeForToken(_ code: String) {
        guard let tokenUrl = URL(string: "\(AuthConfig.baseUrl)\(AuthConfig.tokenEndpoint)") else {
            handleError(.invalidURLComponents)
            return
        }

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "client_id":  loadClientId(),
            "code": code,
            "redirect_uri": AuthConfig.redirectUri,
            "code_verifier": codeVerifier ?? ""
        ]

        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.handleError(.networkError(error.localizedDescription))
                    return
                }

                guard let data = data else {
                    self.handleError(.unknownError)
                    return
                }

                self.handleTokenResponse(data: data)
            }
        }.resume()
    }

    private func handleTokenResponse(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let accessToken = json["access_token"] as? String {
                    self.accessToken = accessToken
                    self.isAuthenticated = true
                } else {
                    let errorDescription = json["error_description"] as? String ?? "Unknown error occurred"
                    self.handleError(.tokenExchangeFailed(errorDescription))
                }
            }
        } catch {
            self.handleError(.unknownError)
        }
    }

    func logout() {
        accessToken = nil
        isAuthenticated = false
        codeVerifier = nil
        codeChallenge = nil
    }

    private func generateCodeVerifier() {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        codeVerifier = Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let verifier = codeVerifier else {
            handleError(.unknownError)
            return
        }

        let challengeHash = SHA256.hash(data: Data(verifier.utf8))
        codeChallenge = Data(challengeHash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func handleError(_ error: AuthError) {
        self.error = error.localizedDescription
        print("Error: \(error.localizedDescription)")
    }

    func loadClientId() -> String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let clientId = dict["ClientID"] as? String else {
            print("Failed to load ClientID from Secrets.plist")
            return ""
        }
        return clientId
    }
}

extension AuthViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}
