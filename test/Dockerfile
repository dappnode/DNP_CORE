FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    iptables iproute2 procps python3 systemd shellcheck && rm -rf /var/lib/apt/lists/*
WORKDIR /tests
COPY src/scripts/mitigate_cve_2026_98432.sh /tests/mitigate.sh
COPY src/upgrades/upgrade_014.sh /tests/upgrade_014.sh
COPY src/entrypoint.sh /tests/entrypoint.sh
COPY test/test_mitigation.py /tests/test_mitigation.py
ENV DAPPNODE_CVE_TEST_CONTAINER=1
CMD ["python3", "-m", "unittest", "-v", "test_mitigation.py"]
