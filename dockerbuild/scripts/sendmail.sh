#!/bin/bash
SERVER='smtp@example.com'
PORT='25'
SENDER_ADDRESS="$1"
RECIPIENT_ADDRESS="$2"
SUBJECT="$3"
MESSAGE="$4"
ATTACHMENT_FILE="$5"

# Build the basic email command
EMAIL_CMD="curl --url \"smtp://$SERVER:$PORT\" \
    --mail-from \"$SENDER_ADDRESS\" \
    --mail-rcpt \"$RECIPIENT_ADDRESS\" \
    --header \"Subject: $SUBJECT\" \
    --header \"From: $SENDER_ADDRESS\" \
    --header \"To: $RECIPIENT_ADDRESS\""

# Handle multiple recipients (comma-separated)
if [[ "$RECIPIENT_ADDRESS" == *","* ]]; then
    # Split by comma and add each recipient
    IFS=',' read -ra ADDR <<< "$RECIPIENT_ADDRESS"
    EMAIL_CMD="curl --url \"smtp://$SERVER:$PORT\" \
    --mail-from \"$SENDER_ADDRESS\""

    for i in "${ADDR[@]}"; do
        # Trim whitespace
        RCPT=$(echo "$i" | sed 's/^ *//;s/ *$//')
        EMAIL_CMD+=" \
    --mail-rcpt \"$RCPT\""
    done

    EMAIL_CMD+=" \
    --header \"Subject: $SUBJECT\" \
    --header \"From: $SENDER_ADDRESS\" \
    --header \"To: $RECIPIENT_ADDRESS\""
fi

# Check if attachment is provided
if [ -n "$ATTACHMENT_FILE" ] && [ -f "$ATTACHMENT_FILE" ]; then
    ATTACHMENT_TYPE="$(file --mime-type "$ATTACHMENT_FILE" | sed 's/.*: //')"

    # Add attachment to email command
    EMAIL_CMD+=" \
    --form '=(;type=multipart/mixed' \
    --form \"=$MESSAGE;type=text/plain\" \
    --form \"file=@$ATTACHMENT_FILE;type=$ATTACHMENT_TYPE;encoder=base64\" \
    --form '=)'"
else
    # Send email without attachment
    EMAIL_CMD+=" \
    --form '=(;type=multipart/mixed' \
    --form \"=$MESSAGE;type=text/plain\" \
    --form '=)'"
fi

# Execute the email command
eval "$EMAIL_CMD"
