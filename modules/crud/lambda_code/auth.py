import json
import os
import boto3
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Lazy-initialised globals — populated inside lambda_handler to avoid
# crashing on cold start when env vars or boto3 aren't available yet.
_cognito = None
_USER_POOL_ID = None
_CLIENT_ID = None


def _get_cognito():
    global _cognito
    if _cognito is None:
        _cognito = boto3.client('cognito-idp')
    return _cognito


def _get_config():
    global _USER_POOL_ID, _CLIENT_ID
    if _USER_POOL_ID is None:
        _USER_POOL_ID = os.environ.get('USER_POOL_ID', '')
        _CLIENT_ID = os.environ.get('CLIENT_ID', '')
        logger.info(f"Auth Lambda initialised — USER_POOL_ID={_USER_POOL_ID[:8]}..., CLIENT_ID={_CLIENT_ID[:8]}...")
    return _USER_POOL_ID, _CLIENT_ID


def lambda_handler(event, context):
    logger.info(f"Auth Lambda invoked — path={event.get('path')}, method={event.get('httpMethod')}")

    # Parse config early so we catch misconfiguration before touching Cognito
    user_pool_id, client_id = _get_config()
    if not user_pool_id or not client_id:
        logger.error("Missing USER_POOL_ID or CLIENT_ID environment variable")
        return response(500, {'error': 'Server misconfiguration — missing Cognito config'})

    cognito = _get_cognito()

    body = json.loads(event.get('body') or '{}')
    username = body.get('username')
    password = body.get('password')
    new_password = body.get('new_password')
    session = body.get('session')

    if not username or not password:
        return response(400, {'error': 'username and password are required'})

    try:
        # If session exists, user is responding to NEW_PASSWORD_REQUIRED challenge
        if session:
            if not new_password:
                return response(400, {'error': 'new_password is required to complete password reset'})

            auth_response = cognito.admin_respond_to_auth_challenge(
                UserPoolId=user_pool_id,
                ClientId=client_id,
                Session=session,
                ChallengeName='NEW_PASSWORD_REQUIRED',
                ChallengeResponses={
                    'USERNAME': username,
                    'NEW_PASSWORD': new_password
                }
            )

            auth_result = auth_response.get('AuthenticationResult', {})
            if not auth_result:
                return response(500, {'error': 'Password reset failed - no token received'})

            return response(200, {
                'id_token': auth_result.get('IdToken'),
                'access_token': auth_result.get('AccessToken'),
                'refresh_token': auth_result.get('RefreshToken'),
                'expires_in': auth_result.get('ExpiresIn'),
                'token_type': auth_result.get('TokenType')
            })

        # Normal login flow — use admin_initiate_auth for compatibility
        # with admin-created users (FORCE_CHANGE_PASSWORD status)
        auth_response = cognito.admin_initiate_auth(
            UserPoolId=user_pool_id,
            ClientId=client_id,
            AuthFlow='ADMIN_USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': username,
                'PASSWORD': password
            }
        )

        logger.info(f"Cognito auth response keys: {list(auth_response.keys())}")
        logger.info(f"ChallengeName: {auth_response.get('ChallengeName', 'none')}")
        logger.info(f"AuthenticationResult present: {'AuthenticationResult' in auth_response}")

        challenge_name = auth_response.get('ChallengeName')
        if challenge_name:
            logger.info(f"Challenge received: {challenge_name}")
            if challenge_name == 'NEW_PASSWORD_REQUIRED':
                return response(400, {
                    'error': 'User must set a new password',
                    'challenge': challenge_name,
                    'session': auth_response.get('Session'),
                    'requires_new_password': True
                })
            return response(400, {
                'error': f'Unexpected challenge: {challenge_name}'
            })

        auth_result = auth_response.get('AuthenticationResult', {})
        if not auth_result:
            logger.error(f"No AuthenticationResult in response. Full response: {json.dumps(auth_response, default=str)}")
            return response(500, {'error': 'Authentication failed - no token received from Cognito'})

        return response(200, {
            'id_token': auth_result.get('IdToken'),
            'access_token': auth_result.get('AccessToken'),
            'refresh_token': auth_result.get('RefreshToken'),
            'expires_in': auth_result.get('ExpiresIn'),
            'token_type': auth_result.get('TokenType')
        })

    except ClientError as error:
        logger.error(f"Cognito ClientError: {error}")
        error_code = error.response['Error']['Code']
        error_message = error.response['Error'].get('Message', '')
        logger.error(f"Error code: {error_code}, message: {error_message}")
        if error_code in ('NotAuthorizedException', 'UserNotFoundException'):
            return response(401, {'error': f'Invalid username or password ({error_code})'})
        if error_code == 'UserNotConfirmedException':
            return response(403, {'error': 'User not confirmed'})
        if error_code == 'PasswordResetRequiredException':
            return response(400, {'error': 'Password reset required'})
        return response(500, {'error': f'{error_code}: {error_message}'})
    except Exception as error:
        logger.error(f"Unexpected error: {error}")
        return response(500, {'error': str(error)})


def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'POST,OPTIONS'
        },
        'body': json.dumps(body)
    }
