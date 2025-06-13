import XCTest
@testable import BotanyBattle

final class JWTValidationTests: XCTestCase {
    
    func testJWTTokenDecoding() {
        // Example JWT payload for testing
        let payload = """
        {
            "sub": "user-123",
            "username": "testuser",
            "email": "test@example.com",
            "iat": 1638360000,
            "exp": 1638363600,
            "aud": "6h2274uf0e73fl2t438orc0oc2",
            "iss": "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_iMuY9Xgu6"
        }
        """
        
        let payloadData = Data(payload.utf8)
        let base64Payload = payloadData.base64EncodedString()
        
        // Simple JWT structure: header.payload.signature
        let mockJWT = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.\(base64Payload).signature"
        
        let claims = extractJWTClaims(from: mockJWT)
        
        XCTAssertEqual(claims?["sub"] as? String, "user-123")
        XCTAssertEqual(claims?["username"] as? String, "testuser")
        XCTAssertEqual(claims?["email"] as? String, "test@example.com")
        XCTAssertEqual(claims?["aud"] as? String, "6h2274uf0e73fl2t438orc0oc2")
    }
    
    func testJWTTokenExpiration() {
        let currentTime = Date().timeIntervalSince1970
        let expiredTime = currentTime - 3600 // 1 hour ago
        let validTime = currentTime + 3600 // 1 hour from now
        
        let expiredPayload = """
        {
            "sub": "user-123",
            "exp": \(Int(expiredTime))
        }
        """
        
        let validPayload = """
        {
            "sub": "user-123",
            "exp": \(Int(validTime))
        }
        """
        
        XCTAssertTrue(isJWTExpired(payload: expiredPayload))
        XCTAssertFalse(isJWTExpired(payload: validPayload))
    }
    
    func testJWTAudienceValidation() {
        let correctAudience = "6h2274uf0e73fl2t438orc0oc2"
        let wrongAudience = "wrong-audience"
        
        let validPayload = """
        {
            "sub": "user-123",
            "aud": "\(correctAudience)"
        }
        """
        
        let invalidPayload = """
        {
            "sub": "user-123",
            "aud": "\(wrongAudience)"
        }
        """
        
        XCTAssertTrue(validateJWTAudience(payload: validPayload, expectedAudience: correctAudience))
        XCTAssertFalse(validateJWTAudience(payload: invalidPayload, expectedAudience: correctAudience))
    }
    
    func testJWTIssuerValidation() {
        let correctIssuer = "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_iMuY9Xgu6"
        let wrongIssuer = "https://malicious-issuer.com"
        
        let validPayload = """
        {
            "sub": "user-123",
            "iss": "\(correctIssuer)"
        }
        """
        
        let invalidPayload = """
        {
            "sub": "user-123",
            "iss": "\(wrongIssuer)"
        }
        """
        
        XCTAssertTrue(validateJWTIssuer(payload: validPayload, expectedIssuer: correctIssuer))
        XCTAssertFalse(validateJWTIssuer(payload: invalidPayload, expectedIssuer: correctIssuer))
    }
    
    func testJWTStructureValidation() {
        let validJWT = "header.payload.signature"
        let invalidJWT1 = "header.payload" // Missing signature
        let invalidJWT2 = "header" // Missing payload and signature
        let invalidJWT3 = "" // Empty string
        
        XCTAssertTrue(isValidJWTStructure(validJWT))
        XCTAssertFalse(isValidJWTStructure(invalidJWT1))
        XCTAssertFalse(isValidJWTStructure(invalidJWT2))
        XCTAssertFalse(isValidJWTStructure(invalidJWT3))
    }
    
    func testJWTSubjectExtraction() {
        let payload = """
        {
            "sub": "user-12345",
            "username": "testuser"
        }
        """
        
        let subject = extractJWTSubject(payload: payload)
        XCTAssertEqual(subject, "user-12345")
        
        let payloadWithoutSub = """
        {
            "username": "testuser"
        }
        """
        
        let missingSubject = extractJWTSubject(payload: payloadWithoutSub)
        XCTAssertNil(missingSubject)
    }
    
    func testJWTTokenRefreshLogic() {
        let currentTime = Date().timeIntervalSince1970
        
        // Token expires in 5 minutes - should refresh
        let soonToExpire = currentTime + 300
        
        // Token expires in 30 minutes - should not refresh
        let validForLonger = currentTime + 1800
        
        // Token already expired - should refresh
        let alreadyExpired = currentTime - 300
        
        XCTAssertTrue(shouldRefreshJWT(expirationTime: soonToExpire, refreshThreshold: 600))
        XCTAssertFalse(shouldRefreshJWT(expirationTime: validForLonger, refreshThreshold: 600))
        XCTAssertTrue(shouldRefreshJWT(expirationTime: alreadyExpired, refreshThreshold: 600))
    }
    
    func testJWTSecurityValidation() {
        // Test for common JWT security issues
        
        // Algorithm confusion attack (none algorithm)
        let noneAlgorithmHeader = """
        {
            "alg": "none",
            "typ": "JWT"
        }
        """
        
        XCTAssertFalse(isSecureJWTAlgorithm(header: noneAlgorithmHeader))
        
        // Valid RS256 algorithm
        let validHeader = """
        {
            "alg": "RS256",
            "typ": "JWT"
        }
        """
        
        XCTAssertTrue(isSecureJWTAlgorithm(header: validHeader))
        
        // Weak HMAC algorithm
        let weakHeader = """
        {
            "alg": "HS256",
            "typ": "JWT"
        }
        """
        
        // HS256 might be acceptable in some contexts, but RS256 is preferred for this app
        XCTAssertFalse(isSecureJWTAlgorithm(header: weakHeader))
    }
}

// MARK: - JWT Utility Functions for Testing

private func extractJWTClaims(from jwt: String) -> [String: Any]? {
    let components = jwt.components(separatedBy: ".")
    guard components.count == 3 else { return nil }
    
    let payloadComponent = components[1]
    
    // Add padding if needed for base64 decoding
    var payload = payloadComponent
    let paddingLength = 4 - (payload.count % 4)
    if paddingLength != 4 {
        payload += String(repeating: "=", count: paddingLength)
    }
    
    guard let payloadData = Data(base64Encoded: payload),
          let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
        return nil
    }
    
    return json
}

private func isJWTExpired(payload: String) -> Bool {
    guard let payloadData = Data(payload.utf8),
          let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
          let exp = json["exp"] as? TimeInterval else {
        return true // Consider invalid tokens as expired
    }
    
    return Date().timeIntervalSince1970 >= exp
}

private func validateJWTAudience(payload: String, expectedAudience: String) -> Bool {
    guard let payloadData = Data(payload.utf8),
          let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
          let aud = json["aud"] as? String else {
        return false
    }
    
    return aud == expectedAudience
}

private func validateJWTIssuer(payload: String, expectedIssuer: String) -> Bool {
    guard let payloadData = Data(payload.utf8),
          let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
          let iss = json["iss"] as? String else {
        return false
    }
    
    return iss == expectedIssuer
}

private func isValidJWTStructure(_ jwt: String) -> Bool {
    let components = jwt.components(separatedBy: ".")
    return components.count == 3 && !components.contains("")
}

private func extractJWTSubject(payload: String) -> String? {
    guard let payloadData = Data(payload.utf8),
          let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
          let sub = json["sub"] as? String else {
        return nil
    }
    
    return sub
}

private func shouldRefreshJWT(expirationTime: TimeInterval, refreshThreshold: TimeInterval) -> Bool {
    let currentTime = Date().timeIntervalSince1970
    let timeUntilExpiration = expirationTime - currentTime
    
    // Refresh if token expires within the threshold or is already expired
    return timeUntilExpiration <= refreshThreshold
}

private func isSecureJWTAlgorithm(header: String) -> Bool {
    guard let headerData = Data(header.utf8),
          let json = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
          let alg = json["alg"] as? String else {
        return false
    }
    
    // Only allow secure asymmetric algorithms
    return alg == "RS256" || alg == "RS384" || alg == "RS512" || 
           alg == "ES256" || alg == "ES384" || alg == "ES512"
}