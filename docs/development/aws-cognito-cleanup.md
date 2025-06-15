# AWS Cognito Cleanup Instructions

This guide provides step-by-step instructions for removing AWS Cognito resources from the AWS console after migrating to Game Center authentication.

## ⚠️ Important Notice

**Before proceeding with cleanup:**
1. Ensure the Game Center migration is complete and tested
2. Verify all applications are using the new Game Center authentication
3. Backup any important user data if needed
4. Consider testing in a development environment first

## Step 1: Identify Cognito Resources

### 1.1 List Current Resources
```bash
# List Cognito User Pools
aws cognito-idp list-user-pools --max-items 10 --region us-west-2

# List Cognito Identity Pools  
aws cognito-identity list-identity-pools --max-results 10 --region us-west-2

# Check SSM parameters
aws ssm get-parameters-by-path --path "/botany-battle" --recursive --region us-west-2
```

### 1.2 Document Resources
Before deletion, document the following for each environment (dev/prod):
- User Pool ID
- User Pool Client ID
- Identity Pool ID
- Associated IAM roles
- SSM parameter names

## Step 2: Remove User Pool Dependencies

### 2.1 Remove User Pool Clients
1. Go to AWS Console → Cognito → User Pools
2. Select the Botany Battle user pool
3. Go to "App integration" → "App clients"
4. Delete all app clients
5. Repeat for each environment

### 2.2 Remove User Pool Triggers
1. In the user pool, go to "User pool properties"
2. Remove any Lambda triggers if configured
3. Save changes

### 2.3 Remove User Pool Domain
1. Go to "App integration" → "Domain"
2. Delete the custom domain if configured
3. Wait for deletion to complete

## Step 3: Delete User Pools

### 3.1 Via AWS Console
1. Go to AWS Console → Cognito → User Pools
2. Select the Botany Battle user pool
3. Click "Delete"
4. Type the user pool name to confirm
5. Click "Delete user pool"
6. Repeat for each environment (dev, prod)

### 3.2 Via AWS CLI
```bash
# Delete user pool (replace with actual pool ID)
aws cognito-idp delete-user-pool \
  --user-pool-id us-west-2_XXXXXXXXX \
  --region us-west-2

# Verify deletion
aws cognito-idp list-user-pools --max-items 10 --region us-west-2
```

## Step 4: Delete Identity Pools

### 4.1 Via AWS Console
1. Go to AWS Console → Cognito → Identity Pools
2. Select the Botany Battle identity pool
3. Click "Delete identity pool"
4. Confirm deletion
5. Repeat for each environment

### 4.2 Via AWS CLI
```bash
# Delete identity pool (replace with actual pool ID)
aws cognito-identity delete-identity-pool \
  --identity-pool-id us-west-2:12345678-1234-1234-1234-123456789012 \
  --region us-west-2

# Verify deletion
aws cognito-identity list-identity-pools --max-results 10 --region us-west-2
```

## Step 5: Remove IAM Roles

### 5.1 Find Cognito-Related Roles
```bash
# List IAM roles with Cognito in the name
aws iam list-roles --query 'Roles[?contains(RoleName, `Cognito`)]'

# List roles created for the project
aws iam list-roles --query 'Roles[?contains(RoleName, `botany-battle`)]'
```

### 5.2 Delete IAM Roles
```bash
# Detach policies first
aws iam list-attached-role-policies --role-name ROLE_NAME
aws iam detach-role-policy --role-name ROLE_NAME --policy-arn POLICY_ARN

# Delete role
aws iam delete-role --role-name ROLE_NAME
```

### 5.3 Remove IAM Policies
```bash
# List custom policies for the project
aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `botany-battle`)]'

# Delete custom policies
aws iam delete-policy --policy-arn POLICY_ARN
```

## Step 6: Clean Up SSM Parameters

### 6.1 Remove Cognito Parameters
```bash
# Remove Cognito-related SSM parameters
aws ssm delete-parameter --name "/botany-battle/dev/cognito/user-pool-id" --region us-west-2
aws ssm delete-parameter --name "/botany-battle/dev/cognito/client-id" --region us-west-2
aws ssm delete-parameter --name "/botany-battle/prod/cognito/user-pool-id" --region us-west-2
aws ssm delete-parameter --name "/botany-battle/prod/cognito/client-id" --region us-west-2

# Verify parameters are removed
aws ssm get-parameters-by-path --path "/botany-battle" --recursive --region us-west-2
```

## Step 7: Clean Up CloudWatch Logs

### 7.1 Remove Cognito Log Groups
```bash
# List log groups related to Cognito
aws logs describe-log-groups --log-group-name-prefix "/aws/cognito" --region us-west-2

# Delete specific log groups if any exist
aws logs delete-log-group --log-group-name "/aws/cognito/userpools/POOL_ID" --region us-west-2
```

## Step 8: Verify Complete Cleanup

### 8.1 Verification Checklist
```bash
# ✅ Verify no user pools remain
aws cognito-idp list-user-pools --max-items 10 --region us-west-2

# ✅ Verify no identity pools remain  
aws cognito-identity list-identity-pools --max-results 10 --region us-west-2

# ✅ Verify no Cognito IAM roles remain
aws iam list-roles --query 'Roles[?contains(RoleName, `Cognito`)]'

# ✅ Verify no Cognito SSM parameters remain
aws ssm get-parameters-by-path --path "/botany-battle" --recursive --region us-west-2 | grep -i cognito

# ✅ Check for any remaining Cognito resources
aws resourcegroupstaggingapi get-resources --resource-type-filters cognito-idp cognito-identity --region us-west-2
```

### 8.2 Cost Verification
1. Go to AWS Console → Billing → Cost Explorer
2. Filter by service: "Amazon Cognito"
3. Verify no charges after cleanup date
4. Set up billing alerts if needed

## Step 9: Update Monitoring and Alerts

### 9.1 Remove Cognito Monitoring
1. Go to AWS Console → CloudWatch → Alarms
2. Remove any alarms related to Cognito metrics
3. Update custom dashboards to remove Cognito widgets

### 9.2 Update Documentation
1. Update architecture diagrams
2. Remove Cognito from disaster recovery plans
3. Update security documentation
4. Update operational runbooks

## Rollback Plan (Emergency Only)

### If Rollback is Needed:
1. **Do NOT proceed with cleanup** until Game Center is fully tested
2. Keep CloudFormation templates for quick restoration
3. Document all resource IDs before deletion
4. Test rollback procedure in development first

### Emergency Restoration:
```bash
# Re-deploy Cognito resources using CloudFormation
aws cloudformation create-stack \
  --stack-name botany-battle-cognito-restore \
  --template-body file://cognito-backup-template.json \
  --parameters file://cognito-backup-parameters.json \
  --capabilities CAPABILITY_IAM
```

## Post-Cleanup Actions

### 9.1 Security Review
- [ ] Review IAM permissions for any lingering Cognito references
- [ ] Update security policies and procedures
- [ ] Review application logs for any Cognito-related errors

### 9.2 Cost Optimization
- [ ] Verify cost reduction from Cognito removal
- [ ] Update budget forecasts
- [ ] Review other potential optimizations

### 9.3 Team Communication
- [ ] Notify team of completed migration
- [ ] Update development procedures
- [ ] Schedule post-migration review meeting

## Support and Troubleshooting

### Common Issues:
1. **Resources still exist after deletion**: Wait 5-10 minutes and check again
2. **IAM role deletion fails**: Ensure all policies are detached first
3. **Access denied errors**: Check IAM permissions for cleanup operations

### Getting Help:
- AWS Support (if you have a support plan)
- AWS Developer Forums
- Internal team documentation in `/docs/troubleshooting/`

### Emergency Contacts:
- AWS Account Administrator: [Contact Info]
- Project Lead: [Contact Info]
- DevOps Team: [Contact Info]

---

**⚠️ Remember: This cleanup is irreversible. Ensure thorough testing of Game Center authentication before proceeding.**