// SSL Key constants
const BASE_KEY_PATH = '/Users/<user>/letsencrypt/config/live';
const KEY_DOMAIN = 'YOURDOMAIN.com';
const CA_PATH = '$BASE_KEY_PATH/letsencryptauthorityx3.pem';
const SSL_CERT_PATH = '$BASE_KEY_PATH/$KEY_DOMAIN/cert.pem';
const SSL_KEY_PATH = '$BASE_KEY_PATH/$KEY_DOMAIN/privkey.pem';
const SSL_FULL_CHAIN_PATH = '$BASE_KEY_PATH/$KEY_DOMAIN/fullchain.pem';
const SSL_CHAIN_PATH = '$BASE_KEY_PATH/$KEY_DOMAIN/chain.pem';
const SSL_PORT = 443;

// Auth redirect
const REDIRECT_HOST = 'auth';
const REDIRECT_BASE = 'https://$REDIRECT_HOST.$KEY_DOMAIN/v1/auth/';
// Client redirect after successful login
const CLIENT_REDIRECT_BASE = 'https://$REDIRECT_HOST.$KEY_DOMAIN/v1/';

// WWW host
const WWW_HOST = 'https://www.$KEY_DOMAIN/';

// This needs to be identical to the client configuration for
// redirects to work on iOS/Android/Mac
const CUSTOM_SCHEME = 'com.YOURDOMAIN.api://redirect/';
