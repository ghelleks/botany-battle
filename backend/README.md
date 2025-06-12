# Botany Battle Backend

Serverless backend for the Botany Battle game, built with AWS Lambda, API Gateway, DynamoDB, and Cognito.

## Prerequisites

- Node.js 18.x
- AWS CLI configured with appropriate credentials
- Serverless Framework CLI
- Redis (for local development)

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. Deploy to AWS:
   ```bash
   npm run deploy:dev
   ```

## Development

### Local Development

1. Start local development server:
   ```bash
   serverless offline
   ```

2. Run tests:
   ```bash
   # Run all tests
   npm test
   
   # Run unit tests
   npm run test:unit
   
   # Run integration tests
   npm run test:integration
   
   # Run load tests
   npm run test:load
   ```

3. Lint code:
   ```bash
   npm run lint
   ```

4. Format code:
   ```bash
   npm run format
   ```

### Project Structure

```
src/
├── functions/
│   ├── auth/        # Authentication handlers
│   ├── game/        # Game logic handlers
│   ├── plant/       # Plant data handlers
│   └── shop/        # Shop handlers
├── lib/            # Shared libraries
└── utils/          # Utility functions
```

### Testing

- Unit tests: `**/__tests__/**/*.test.ts`
- Integration tests: `**/__tests__/**/*.integration.test.ts`
- Load tests: `**/__tests__/**/*.load.test.ts`

### Deployment

1. Deploy to development:
   ```bash
   npm run deploy:dev
   ```

2. Deploy to production:
   ```bash
   npm run deploy:prod
   ```

## API Documentation

### Authentication

- `POST /auth`
  - Authenticate user with Cognito
  - Returns JWT token

### Game

- `POST /game`
  - Create new game
  - Join existing game
  - Submit answer

### Plant

- `GET /plant`
  - Get random plant
  - Get plant by ID
  - Search plants

### Shop

- `POST /shop`
  - Purchase item
  - Get inventory
  - Get shop items

## Monitoring

- CloudWatch metrics
- X-Ray tracing
- Custom metrics
- Error tracking

## Security

- Cognito authentication
- JWT validation
- API Gateway rate limiting
- CORS configuration
- Input validation

## Contributing

1. Create feature branch
2. Write tests
3. Implement feature
4. Ensure tests pass
5. Submit pull request

## License

MIT 