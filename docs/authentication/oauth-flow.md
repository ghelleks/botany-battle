# OAuth 2.0 Authentication Flow

## Overview
Botany Battle uses AWS Cognito as the OAuth 2.0 provider for secure user authentication. This document outlines the complete authentication flow for both iOS and backend systems.

## Authentication Architecture

### Components
- **AWS Cognito User Pool**: Central identity provider
- **iOS App**: Client application using Amplify SDK
- **Backend API**: Resource server with JWT validation
- **Refresh Token Management**: Automatic token renewal

## OAuth 2.0 Flow Implementation

### 1. User Registration (Sign Up)
```
iOS App -> AWS Cognito User Pool
1. User enters registration details
2. App calls Amplify.Auth.signUp()
3. Cognito creates user account
4. Email verification required
5. User confirms account via email
```

### 2. User Authentication (Sign In)
```
iOS App -> AWS Cognito User Pool -> Backend API
1. User enters credentials
2. App calls Amplify.Auth.signIn()
3. Cognito validates credentials
4. Returns JWT tokens (ID, Access, Refresh)
5. App stores tokens securely
6. App includes Access token in API requests
```

### 3. Token Management
```
iOS App -> AWS Cognito
1. Access tokens expire after 1 hour
2. App automatically refreshes using Refresh token
3. Refresh tokens are long-lived (30 days)
4. Silent token renewal in background
```

### 4. Logout Flow
```
iOS App -> AWS Cognito
1. User initiates logout
2. App calls Amplify.Auth.signOut()
3. Local tokens are cleared
4. User redirected to login screen
```

## Security Configuration

### AWS Cognito User Pool Settings
- **Pool ID**: `us-west-2_iMuY9Xgu6`
- **Client ID**: `6h2274uf0e73fl2t438orc0oc2`
- **Password Policy**: Minimum 8 characters, uppercase, lowercase, numbers
- **MFA**: Optional (can be enabled)
- **Account Recovery**: Email-based

### JWT Token Configuration
- **ID Token**: Contains user identity claims
- **Access Token**: Used for API authorization
- **Refresh Token**: Long-lived token for renewal
- **Token Expiration**: 
  - Access Token: 1 hour
  - ID Token: 1 hour
  - Refresh Token: 30 days

### Security Headers
All API requests include:
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

## Implementation Details

### iOS Integration (Amplify)
```swift
// Configuration
Amplify.configure(with: amplifyconfiguration)

// Sign Up
let result = try await Amplify.Auth.signUp(
    username: username,
    password: password,
    options: .init(userAttributes: [
        AuthUserAttribute(.email, value: email)
    ])
)

// Sign In
let result = try await Amplify.Auth.signIn(
    username: username,
    password: password
)

// Get Current User
let user = try await Amplify.Auth.getCurrentUser()
```

### Backend JWT Validation
```javascript
// Lambda authorizer validates JWT tokens
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

const client = jwksClient({
    jwksUri: 'https://cognito-idp.us-west-2.amazonaws.com/us-west-2_iMuY9Xgu6/.well-known/jwks.json'
});

// Validate token signature and claims
const decoded = jwt.verify(token, getKey, {
    audience: '6h2274uf0e73fl2t438orc0oc2',
    issuer: 'https://cognito-idp.us-west-2.amazonaws.com/us-west-2_iMuY9Xgu6'
});
```

## Error Handling

### Common Authentication Errors
1. **InvalidPasswordException**: Password doesn't meet policy
2. **UsernameExistsException**: Username already taken
3. **UserNotConfirmedException**: Email not verified
4. **NotAuthorizedException**: Invalid credentials
5. **UserNotFoundException**: User doesn't exist
6. **TokenRefreshException**: Refresh token expired

### Error Response Format
```json
{
    "error": "NotAuthorizedException",
    "message": "Invalid credentials provided",
    "statusCode": 401
}
```

## Testing Strategy

### Unit Tests
- Token validation logic
- Error handling scenarios
- User state management

### Integration Tests
- End-to-end authentication flow
- Token refresh scenarios
- API authorization

### Security Tests
- Token tampering detection
- Expired token handling
- Cross-user authorization prevention

## Monitoring and Logging

### CloudWatch Metrics
- Authentication success/failure rates
- Token refresh frequency
- Error distribution by type

### Security Monitoring
- Failed login attempts
- Suspicious activity patterns
- Token usage anomalies

## Compliance and Privacy

### Data Protection
- Passwords are never stored in plaintext
- JWT tokens contain minimal user data
- Secure token storage on device

### GDPR Compliance
- User data deletion capability
- Data export functionality
- Privacy-first design principles

## Best Practices

### Client-Side Security
- Store tokens in iOS Keychain
- Implement biometric authentication
- Clear tokens on app uninstall

### Server-Side Security
- Validate all JWT tokens
- Implement rate limiting
- Log security events

### Development Guidelines
- Use HTTPS everywhere
- Rotate signing keys regularly
- Monitor token usage patterns