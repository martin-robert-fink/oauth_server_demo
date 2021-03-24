# The SSL keys are all protected so this needs to run as root, hence sudo
# In real life, the server would be started with launchd as process
# For development, we need to ignore the dart/flutter warning to not run as root
# It's the only/best way to get at the SSL keys
sudo dart run bin/main.dart