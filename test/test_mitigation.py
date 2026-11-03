"""Harmless packet and lifecycle tests; run only in the disposable privileged container."""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import tempfile
import unittest

SCRIPT = "/tests/mitigate.sh"
STATE = Path("/var/lib/dappnode/cve-2026-98432")
RULE = ["-p", "tcp", "-m", "u32", "--u32", "0>>24&0x0f=6:15", "-m", "comment", "--comment", "dappnode-cve-2026-98432", "-j", "DROP"]


def run(*args, check=True, env=None):
    return subprocess.run(args, text=True, capture_output=True, check=check, env=env)


@unittest.skipUnless(os.environ.get("DAPPNODE_CVE_TEST_CONTAINER") == "1" and Path("/.dockerenv").exists(), "disposable privileged Docker container required")
class MitigationTests(unittest.TestCase):
    def setUp(self):
        for chain in ("PREROUTING", "OUTPUT"):
            while run("iptables", "-t", "raw", "-C", chain, *RULE, check=False).returncode == 0:
                run("iptables", "-t", "raw", "-D", chain, *RULE)
        shutil.rmtree(STATE, ignore_errors=True)
        Path("/usr/src/dappnode/DNCORE/security").mkdir(parents=True, exist_ok=True)
        Path("/usr/src/dappnode/DNCORE/security/cve-2026-98432.status").unlink(missing_ok=True)
        # Exercise systemd wiring without needing PID 1 to be systemd in Docker.
        Path("/usr/local/bin/systemctl").write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> /tmp/systemctl-calls\nexit 0\n')
        Path("/usr/local/bin/systemctl").chmod(0o755)
        Path("/usr/local/bin/sysctl").unlink(missing_ok=True)
        run("/usr/sbin/sysctl", "-w", "net.ipv4.tcp_migrate_req=1")

    def install(self):
        result = run("bash", SCRIPT, "install")
        self.assertIn("Temporary mitigation installed", result.stdout)
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "mitigated")

    def test_lifecycle_reapply_detection_and_rollback(self):
        self.install()
        original = STATE / "net.ipv4.tcp_migrate_req.original"
        self.assertEqual(original.read_text().strip(), "1")
        self.assertEqual(run("sysctl", "-n", "net.ipv4.tcp_migrate_req").stdout.strip(), "0")
        # Missing MPTCP is supported; never fabricate a sysctl on such kernels.
        if run("sysctl", "-n", "net.mptcp.enabled", check=False).returncode:
            self.assertNotIn("net.mptcp.enabled", Path("/etc/sysctl.d/99-dappnode-cve-2026-98432.conf").read_text())
        run("bash", SCRIPT, "install")
        self.assertEqual(original.read_text().strip(), "1")
        self.assertEqual(run("iptables", "-t", "raw", "-S").stdout.count("dappnode-cve-2026-98432"), 2)
        run("systemd-analyze", "verify", "/etc/systemd/system/dappnode-cve-2026-98432.service", "/etc/systemd/system/dappnode-cve-2026-98432.timer")
        run("iptables", "-t", "raw", "-D", "PREROUTING", *RULE)
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "failed")
        run("bash", SCRIPT, "apply")
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "mitigated")
        run("bash", SCRIPT, "remove")
        self.assertEqual(run("sysctl", "-n", "net.ipv4.tcp_migrate_req").stdout.strip(), "1")
        self.assertNotIn("dappnode-cve-2026-98432", run("iptables", "-t", "raw", "-S").stdout)
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "removed")
        run("bash", SCRIPT, "remove")  # Idempotent removal.
        run("bash", SCRIPT, "install")  # Core replay respects an explicit rollback.
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "removed")

    def test_failed_apply_is_not_reported_as_mitigated(self):
        Path("/usr/local/bin/sysctl").write_text('#!/bin/sh\ncase "$*" in "-w net.ipv4.tcp_migrate_req=0") exit 1;; esac\nexec /usr/sbin/sysctl "$@"\n')
        Path("/usr/local/bin/sysctl").chmod(0o755)
        result = run("bash", SCRIPT, "install", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "failed")
        self.assertTrue((STATE / "net.ipv4.tcp_migrate_req.original").exists())
        Path("/usr/local/bin/sysctl").unlink()
        run("bash", SCRIPT, "install")  # Retry after a partial failure.
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "mitigated")

    def test_host_forwarded_and_loopback_packets(self):
        self.install()
        servers = []
        try:
            run("ip", "netns", "add", "peer")
            run("ip", "netns", "add", "backend")
            for namespace, subnet in (("peer", "10.90.0"), ("backend", "10.91.0")):
                host = "cv-" + namespace
                run("ip", "link", "add", host, "type", "veth", "peer", "name", "eth0", "netns", namespace)
                run("ip", "addr", "add", subnet + ".1/24", "dev", host)
                run("ip", "link", "set", host, "up")
                run("ip", "-n", namespace, "addr", "add", subnet + ".2/24", "dev", "eth0")
                run("ip", "-n", namespace, "link", "set", "eth0", "up")
                run("ip", "-n", namespace, "link", "set", "lo", "up")
                run("ip", "-n", namespace, "route", "add", "default", "via", subnet + ".1")
            run("sysctl", "-w", "net.ipv4.ip_forward=1")
            # Model Docker's published port: incoming TCP is DNATed to another namespace.
            nat = ["-i", "cv-peer", "-p", "tcp", "--dport", "18081", "-j", "DNAT", "--to-destination", "10.91.0.2:18081"]
            run("iptables", "-t", "nat", "-A", "PREROUTING", *nat)
            servers.append(subprocess.Popen(["python3", "-m", "http.server", "18080", "--bind", "0.0.0.0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            servers.append(subprocess.Popen(["ip", "netns", "exec", "backend", "python3", "-m", "http.server", "18081", "--bind", "0.0.0.0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            time.sleep(0.5)
            for prefix, address, port in ((["ip", "netns", "exec", "peer"], "10.90.0.1", 18080), (["ip", "netns", "exec", "peer"], "10.90.0.1", 18081), ([], "127.0.0.1", 18080)):
                for options in (False, True):
                    code = f'''import socket
s=socket.socket(); s.settimeout(1)
s.setsockopt(socket.IPPROTO_TCP, socket.TCP_MAXSEG, 1200)
if {options}: s.setsockopt(socket.IPPROTO_IP, socket.IP_OPTIONS, bytes([1,1,1,0]))
try:
    s.connect(({address!r}, {port})); s.sendall(b"GET / HTTP/1.0\\r\\n\\r\\n"); data=s.recv(100); assert data
except (TimeoutError, OSError):
    raise SystemExit(1)
'''
                    result = run(*prefix, "python3", "-c", code, check=False)
                    self.assertEqual(result.returncode, 1 if options else 0, result.stderr)
            counters = run("iptables", "-t", "raw", "-L", "-n", "-v", "-x").stdout
            drops = [int(line.split()[0]) for line in counters.splitlines() if "dappnode-cve-2026-98432" in line]
            self.assertEqual(len(drops), 2)
            self.assertTrue(all(count > 0 for count in drops), counters)
        finally:
            for server in servers:
                server.terminate()
                server.wait()
            for namespace in ("peer", "backend"):
                run("ip", "netns", "del", namespace, check=False)
            run("iptables", "-t", "nat", "-D", "PREROUTING", *nat, check=False) if "nat" in locals() else None

    def test_persistence_failure_stays_visible_even_when_rules_are_live(self):
        Path("/usr/local/bin/systemctl").write_text('#!/bin/sh\nexit 1\n')
        result = run("bash", SCRIPT, "install", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "failed")

    def test_entrypoint_starts_manager_before_reporting_upgrade_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for child in ("upgrades", "scripts", "deb", "bin"):
                (root / child).mkdir()
            (root / "upgrades/upgrade_014.sh").write_text("exit 17\n")
            (root / "scripts/noop.sh").write_text("exit 0\n")
            (root / "packages-content-hash.csv").write_text("")
            for name, body in {
                "sleep": "exit 0",
                "docker": "echo false",
                "docker-compose": "echo manager-started"
            }.items():
                stub = root / "bin" / name
                stub.write_text("#!/bin/sh\n" + body + "\n")
                stub.chmod(0o755)
            Path("/usr/src/dappnode/DNCORE/docker-compose-dappmanager.yml").write_text("image: example:1\n")
            env = dict(os.environ, PATH=str(root / "bin") + ":" + os.environ["PATH"])
            result = subprocess.run(["bash", "/tests/entrypoint.sh"], cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("manager-started", result.stdout)
            self.assertIn("upgrade_014.sh failed", result.stderr)
            env["DISABLE_HOST_SCRIPTS"] = "true"
            result = subprocess.run(["bash", "/tests/entrypoint.sh"], cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)

    def test_non_ubuntu_is_skipped(self):
        path = Path("/etc/os-release")
        original = path.read_text()
        try:
            path.write_text('ID=debian\nVERSION_CODENAME=bookworm\n')
            run("bash", SCRIPT, "install")
            self.assertEqual(run("bash", SCRIPT, "status").stdout.strip(), "not-applicable")
            self.assertNotIn("dappnode-cve-2026-98432", run("iptables", "-t", "raw", "-S").stdout)
        finally:
            path.write_text(original)
