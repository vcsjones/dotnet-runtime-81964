FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wget libc6 libgcc1 libgssapi-krb5-2 libicu66 libssl1.1 libstdc++6 zlib1g ca-certificates lsb-core lldb ubuntu-dbgsym-keyring

RUN echo "deb http://ddebs.ubuntu.com $(lsb_release -cs) main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
RUN echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-updates main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list
RUN echo "deb http://ddebs.ubuntu.com $(lsb_release -cs)-proposed main restricted universe multiverse" | tee -a /etc/apt/sources.list.d/ddebs.list

# Install some debugging symbols for openssl.
RUN apt-get update && apt-get install -y libssl-dev libssl1.1-dbgsym

RUN mkdir /app && mkdir /dotnet && mkdir /usr/local/dotnet
WORKDIR /dotnet
RUN wget https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh -c 7.0 -i /usr/local/dotnet

ENV DOTNET_ROOT=/usr/local/dotnet
ENV PATH=/usr/local/dotnet:${PATH}
WORKDIR /app
RUN rm -rf /dotnet

COPY openssl.cnf openssl.cnf
# Make a root. OpenSSL will do smart things and add a basicConstraints
RUN openssl req -new -x509 -keyout root.key -out root.cer -nodes -subj /CN=Kevins\ Happy\ CA

# Make a leaf request
RUN openssl req -new -keyout leaf.key -nodes -subj /CN=potato.vcsjones.dev -out leaf.csr

# Issue the leaf with the OCSP extension config.
RUN openssl x509 -req -days 365 -in leaf.csr -CA root.cer -CAkey root.key -set_serial 42 -out leaf.cer -extfile openssl.cnf -extensions usr_cert

# Install the root.
RUN cp root.cer /usr/local/share/ca-certificates/our-root.crt && update-ca-certificates

# Get rid of the stuff we aren't using.
RUN rm leaf.csr root.key root.cer openssl.cnf

# Bundle it all up in to a PKCS12
RUN openssl pkcs12 -export -in leaf.cer -inkey leaf.key -password pass:potato -out leaf.p12

RUN dotnet new webapp
COPY appsettings.json appsettings.json
RUN rm appsettings.Development.json

CMD dotnet run
