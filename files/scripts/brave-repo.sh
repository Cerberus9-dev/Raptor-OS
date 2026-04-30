#!/bin/bash
set -oue pipefail

curl -Lo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
