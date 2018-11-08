#!/bin/bash

### CA file to install (customize!)
### NOTE: put the cert file in the same location like this script!

CERT_FILE="root.cert.pem"
CERT_NAME="My Root CA"

### install certificate on linux system

sudo mkdir /usr/local/share/ca-certificates/extra
sudo cp ${CERT_FILE} /usr/local/share/ca-certificates/extra/root.cert.crt
sudo update-ca-certificates

### to modfy the cert db it require “certutil”-Tool its included in this package

sudo apt install libnss3-tools

### Script installs root.cert.pem to certificate trust store of applications using NSS
### (e.g. Firefox, Thunderbird, Chromium)
### Mozilla uses cert8, Chromium and Chrome use cert9
### /home/<user>/.pki/nssdb/cert9.db is the chrome db!

###
### For cert8 (legacy - DBM)
###

for certDB in $(find ~/ -name "cert8.db")
do
    certdir=$(dirname ${certDB});
    certutil -A -n "${certname}" -t "TCu,Cu,Tu" -i ${CERT_FILE} -d dbm:${certdir}
done


###
### For cert9 (SQL)
###

for certDB in $(find ~/ -name "cert9.db")
do
    certdir=$(dirname ${certDB});
    certutil -A -n "${certname}" -t "TCu,Cu,Tu" -i ${CERT_FILE} -d sql:${certdir}
done