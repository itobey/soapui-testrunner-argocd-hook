#!/bin/bash

# Default directories
PROJECT_DIR=/tmp/project
REPORTS_DIR=/tmp/reports

# Create directories if they don't exist
mkdir -p $PROJECT_DIR
mkdir -p $REPORTS_DIR

# Function to download and extract the SoapUI project
download_soapui_project() {
    echo "Starting SoapUI project download process..."
    echo "Script executed with user: $(whoami)"

    # Check if required environment variables are set
    if [ -z "$ARTIFACTORY_USER" ] || [ -z "$ARTIFACTORY_PASSWORD" ]; then
        echo "ERROR: Artifactory credentials not provided"
        return 1
    fi

    if [ -z "$MAVEN_GROUP_ID" ] || [ -z "$MAVEN_ARTIFACT_ID" ] || [ -z "$MAVEN_VERSION" ]; then
        echo "ERROR: Maven coordinates not provided"
        return 1
    fi

    REPO="releases"

    # Convert groupId to path format
    GROUP_PATH=$(echo $MAVEN_GROUP_ID | tr '.' '/')

    # Build the download URL
    DOWNLOAD_URL="https://artifactory.example.com:443/artifactory/${REPO}/${GROUP_PATH}/${MAVEN_ARTIFACT_ID}/${MAVEN_VERSION}/${MAVEN_ARTIFACT_ID}-${MAVEN_VERSION}.jar"

    echo "======= DEBUG INFO ======="
    echo "Repository: ${REPO}"
    echo "GroupId: ${GROUP_PATH}"
    echo "ArtifactId: ${MAVEN_ARTIFACT_ID}"
    echo "Version: ${MAVEN_VERSION}"
    echo "Resolved download URL: ${DOWNLOAD_URL}"
    echo "=========================="

    # Create temporary directory
    mkdir -p /tmp/soapui-project

    # Download SoapUI project files from Artifactory with HTTP status code
    echo "Downloading SoapUI project file..."
    HTTP_RESPONSE=$(curl -s -w "%{http_code}" -u ${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD} \
      "${DOWNLOAD_URL}" \
      --create-dirs -o /tmp/soapui-project/soapui-tests.jar)

    # Check download result
    if [ $? -ne 0 ]; then
      echo "ERROR: curl command failed with exit code $?"
      return 1
    fi

    echo "HTTP Status Code: ${HTTP_RESPONSE}"

    if [ "${HTTP_RESPONSE}" != "200" ]; then
      echo "ERROR: Failed to download JAR file. HTTP status code: ${HTTP_RESPONSE}"
      return 1
    fi

    # Verify file exists and has size
    if [ ! -f "/tmp/soapui-project/soapui-tests.jar" ]; then
      echo "ERROR: Downloaded file doesn't exist"
      return 1
    fi

    FILE_SIZE=$(stat -c%s "/tmp/soapui-project/soapui-tests.jar" 2>/dev/null || ls -l "/tmp/soapui-project/soapui-tests.jar" | awk '{print $5}')
    echo "Downloaded JAR file size: ${FILE_SIZE} bytes"

    # Extract XML file and ensure only one exists
    echo "Extracting XML files from JAR..."
    unzip /tmp/soapui-project/soapui-tests.jar "*.xml" -x "*/*" -d $PROJECT_DIR/
    UNZIP_STATUS=$?

    if [ ${UNZIP_STATUS} -ne 0 ]; then
      echo "ERROR: Failed to unzip JAR file. Status code: ${UNZIP_STATUS}"
      echo "JAR file content listing:"
      unzip -l /tmp/soapui-project/soapui-tests.jar || echo "Unable to list JAR contents"
      return 1
    fi

    XML_COUNT=$(ls $PROJECT_DIR/*.xml 2>/dev/null | wc -l)
    echo $(ls $PROJECT_DIR/*.xml)
    echo "Found ${XML_COUNT} XML files in the JAR"

    if [ "${XML_COUNT}" -ne 1 ]; then
      echo "ERROR: Expected exactly one XML file, found ${XML_COUNT}"
      ls -la $PROJECT_DIR/*.xml 2>/dev/null || echo "No XML files found"
      return 1
    else
      XML_FILE=$(ls $PROJECT_DIR/*.xml)
      XML_SIZE=$(stat -c%s "${XML_FILE}" 2>/dev/null || ls -l "${XML_FILE}" | awk '{print $5}')
      echo "Successfully extracted XML file: ${XML_FILE} (${XML_SIZE} bytes)"
      return 0
    fi
}

# Function to send email with test results
send_email() {
    if [ "$EMAIL_ENABLED" != "true" ]; then
        echo "Email notifications are disabled. Skipping email sending."
        return 0
    fi

    # Check if required environment variables are set
    if [ -z "$EMAIL_RECIPIENTS" ]; then
        echo "WARNING: Email recipients not specified. Skipping email sending."
        return 1
    fi

    # Set default email sender if not specified
    EMAIL_SENDER=${EMAIL_SENDER:-"default-user@example.com"}

    # Set subject with optional prefix and project info
    EMAIL_SUBJECT_PREFIX=${EMAIL_SUBJECT_PREFIX:-"SoapUI Test Summary"}
    PROJECT_INFO="$MAVEN_GROUP_ID:$MAVEN_ARTIFACT_ID"

    # Read summary from /tmp/summary.log if it exists
    if [ -f "/tmp/summary.log" ] && [ -s "/tmp/summary.log" ]; then
        echo "Reading test summary from /tmp/summary.log..."
        EMAIL_MESSAGE=$(cat /tmp/summary.log)
        EMAIL_SUBJECT="$EMAIL_SUBJECT_PREFIX - $PROJECT_INFO"
    else
        echo "Summary log not found or empty. Using default message."
        EMAIL_MESSAGE="Finished SoapUI Tests, but no summary is available."
        EMAIL_SUBJECT="$EMAIL_SUBJECT_PREFIX - $PROJECT_INFO"
    fi

    # Create zip of all reports
    echo "Creating zip file of reports..."
    zip -rj ${REPORTS_DIR}/reports.zip ${REPORTS_DIR}/* || true

    # Send email with summary content and reports attached
    echo "Sending email with summary content and reports attached..."
    ./sendmail.sh "$EMAIL_SENDER" "$EMAIL_RECIPIENTS" "$EMAIL_SUBJECT" "$EMAIL_MESSAGE" "${REPORTS_DIR}/reports.zip"

    echo "Email sent to: ${EMAIL_RECIPIENTS}"
    return 0
}

# Main execution flow
main() {
    echo "Starting SoapUI test runner with integrated downloader and email sender..."

    # Step 1: Download the SoapUI project
    echo "Downloading SoapUI project..."
    download_soapui_project
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to download SoapUI project"
        send_email
        exit 1
    fi

    # Step 2: Run SoapUI tests by calling the original EntryPoint.sh
    echo "Running SoapUI tests using the original EntryPoint.sh..."

    # Call original EntryPoint.sh and capture its exit code
    ./EntryPoint.sh 2>&1 | tee /dev/stderr | grep -E "Total.*:|.*Summary" > /tmp/summary.log
    TEST_EXIT_CODE=${PIPESTATUS[0]}
    echo "SoapUI test execution completed with exit code: $TEST_EXIT_CODE"

    # Step 3: Send email with results
    send_email

    # Step 4: Forward the exit code from EntryPoint.sh
    if [ $TEST_EXIT_CODE -ne 0 ]; then
        echo "Exiting with code $TEST_EXIT_CODE (received from EntryPoint.sh)"
        exit $TEST_EXIT_CODE
    fi

    echo "SoapUI test execution completed successfully"
    exit 0
}

# Start execution
main 2>&1 | tee ${REPORTS_DIR}/console-log.log
