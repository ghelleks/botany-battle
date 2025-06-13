import {
  CognitoIdentityProviderClient,
  CreateUserPoolCommand,
  CreateUserPoolClientCommand,
} from "@aws-sdk/client-cognito-identity-provider";
import { SSMClient, PutParameterCommand } from "@aws-sdk/client-ssm";

const REGION = "us-west-2";
const cognitoClient = new CognitoIdentityProviderClient({ region: REGION });
const ssmClient = new SSMClient({ region: REGION });

async function setupCognito(): Promise<void> {
  try {
    // Create User Pool
    const createPoolCommand = new CreateUserPoolCommand({
      PoolName: "botany-battle-user-pool",
      Policies: {
        PasswordPolicy: {
          MinimumLength: 8,
          RequireUppercase: true,
          RequireLowercase: true,
          RequireNumbers: true,
          RequireSymbols: true,
        },
      },
      Schema: [
        {
          Name: "email",
          AttributeDataType: "String",
          Required: true,
          Mutable: true,
        },
      ],
      AutoVerifiedAttributes: ["email"],
    });

    const userPool = await cognitoClient.send(createPoolCommand);
    const userPoolId = userPool.UserPool?.Id;

    if (!userPoolId) {
      throw new Error("Failed to create User Pool");
    }

    // Create User Pool Client
    const createClientCommand = new CreateUserPoolClientCommand({
      UserPoolId: userPoolId,
      ClientName: "botany-battle-client",
      GenerateSecret: false,
      ExplicitAuthFlows: [
        "ALLOW_USER_PASSWORD_AUTH",
        "ALLOW_REFRESH_TOKEN_AUTH",
      ],
    });

    const userPoolClient = await cognitoClient.send(createClientCommand);
    const clientId = userPoolClient.UserPoolClient?.ClientId;

    if (!clientId) {
      throw new Error("Failed to create User Pool Client");
    }

    // Store IDs in SSM Parameter Store
    const putUserPoolIdCommand = new PutParameterCommand({
      Name: "/botany-battle/dev/cognito/user-pool-id",
      Value: userPoolId,
      Type: "String",
      Overwrite: true,
    });

    const putClientIdCommand = new PutParameterCommand({
      Name: "/botany-battle/dev/cognito/client-id",
      Value: clientId,
      Type: "String",
      Overwrite: true,
    });

    await ssmClient.send(putUserPoolIdCommand);
    await ssmClient.send(putClientIdCommand);

    console.log("Cognito setup completed successfully:");
    console.log("User Pool ID:", userPoolId);
    console.log("Client ID:", clientId);
  } catch (error) {
    console.error("Error setting up Cognito:", error);
    process.exit(1);
  }
}

setupCognito();
