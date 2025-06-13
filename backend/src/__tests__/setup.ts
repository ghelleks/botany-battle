// Mock environment variables
process.env.COGNITO_CLIENT_ID = "test-client-id";
process.env.COGNITO_USER_POOL_ID = "test-user-pool-id";
process.env.STAGE = "test";
process.env.REGION = "us-west-2";

// Global test timeout
jest.setTimeout(10000);

// Mock console.error to keep test output clean
console.error = jest.fn();
