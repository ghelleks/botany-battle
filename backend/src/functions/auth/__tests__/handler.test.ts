import { APIGatewayProxyEvent } from "aws-lambda";
import { handler } from "../handler";

// Mock Cognito at module level
jest.mock("@aws-sdk/client-cognito-identity-provider", () => ({
  CognitoIdentityProviderClient: jest.fn().mockImplementation(() => ({
    send: jest.fn().mockResolvedValue({
      AuthenticationResult: {
        IdToken: "mock-token",
      },
    }),
  })),
  InitiateAuthCommand: jest.fn(),
}));

describe("Auth Handler", () => {
  const mockEvent = (body: any): APIGatewayProxyEvent => ({
    body: body ? JSON.stringify(body) : null,
    headers: {},
    multiValueHeaders: {},
    httpMethod: "POST",
    isBase64Encoded: false,
    path: "/auth",
    pathParameters: null,
    queryStringParameters: null,
    multiValueQueryStringParameters: null,
    stageVariables: null,
    requestContext: {
      accountId: "",
      apiId: "",
      authorizer: null,
      protocol: "",
      httpMethod: "",
      identity: {
        accessKey: null,
        accountId: null,
        apiKey: null,
        apiKeyId: null,
        caller: null,
        clientCert: null,
        cognitoAuthenticationProvider: null,
        cognitoAuthenticationType: null,
        cognitoIdentityId: null,
        cognitoIdentityPoolId: null,
        principalOrgId: null,
        sourceIp: "",
        user: null,
        userAgent: null,
        userArn: null,
      },
      path: "",
      stage: "",
      requestId: "",
      requestTimeEpoch: 0,
      resourceId: "",
      resourcePath: "",
    },
    resource: "",
  });

  it("should return 400 if request body is missing", async () => {
    const event = mockEvent(null);
    const response = await handler(event);

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body)).toEqual({
      message: "Request body is required",
    });
  });

  it("should return 400 if username or password is missing", async () => {
    const event = mockEvent({ username: "test" });
    const response = await handler(event);

    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body)).toEqual({
      message: "Username and password are required",
    });
  });

  it("should return 200 with token on successful authentication", async () => {
    const event = mockEvent({
      username: "testuser",
      password: "testpass",
    });

    const response = await handler(event);

    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body)).toEqual({
      message: "Authentication successful",
      token: "mock-token",
    });
  });
});
