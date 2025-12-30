# This script is originally from the SoapUI Docker image.
# Because it originally contains exit commands it can not be used from the custom entrypoint script, because it would exit the container.
# For this reason it is copied to the project directory, modified, and mounted in the container.
# https://github.com/SmartBear/soapui/blob/next/docker/Files/EntryPoint.sh
if [ -d "$MOUNTED_PROJECT_DIR" ]; then
  cp -a $MOUNTED_PROJECT_DIR/. $PROJECT_DIR
fi

if [ -d "$MOUNTED_EXT_DIR" ]; then
  cp -a $MOUNTED_EXT_DIR/. $SOAPUI_DIR/bin/ext
fi

sed -i "s|COMMAND_LINE|$COMMAND_LINE|" ./RunProject.sh
sed -i "s|%project%|$PROJECT_DIR|g" ./RunProject.sh
sed -i "s|%reports%|$REPORTS_DIR|g" ./RunProject.sh

./RunProject.sh

export EXIT_CODE=$?

# These lines here are removed so it does not interfere with the custom entrypoint script.
#if [ $EXIT_CODE -eq 1 ]; then
#    exit 102
#fi
#
#if [ $EXIT_CODE != 0 ]; then
#    exit 103
#fi
#
#exit 0