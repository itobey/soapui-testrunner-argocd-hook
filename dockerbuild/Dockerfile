FROM smartbear/soapuios-testrunner:5.9.0

USER root

# Install packages using apt-get
RUN apt-get update && \
    apt-get install -y \
        ca-certificates \
        openssl \
        libssl1.1 \
        curl \
        zip \
        file \
        unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy and set up the scripts
COPY scripts/* ./
RUN chmod +x ./customEntrypoint.sh && \
    chmod +x ./EntryPoint.sh && \
    useradd -u 4444 -r -g root -m -d /home/runner -s /sbin/nologin -c "Runner user" runner && \
    chmod -R 770 /usr/local/SmartBear/* && \
    chgrp -R 0 /usr/local/SmartBear && \
    chmod -R g+rwX /usr/local/SmartBear

USER runner

# Set the custom entrypoint
ENTRYPOINT ["./customEntrypoint.sh"]
