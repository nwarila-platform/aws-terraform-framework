#!/usr/bin/env python3
"""Block until a host is answering SSH, or a deadline elapses.

Used by the Terraform SSH readiness gate (terraform_data.ssh_ready in
terraform/52-resources-aws.tf) so the `terraform apply` step's wall-clock
captures the full instance boot + user_data setup window -- Terraform owns the
"until the system is reachable for Ansible" wait instead of handing an unbounded
wait to a later Ansible step. This probes REACHABILITY ONLY: it opens a TCP
connection to the SSH port and checks for the SSH protocol banner ("SSH-..."). It
does NOT authenticate or log in, so an auth/key problem never fails this gate.

Usage: wait_for_ssh.py <host> [port=22] [timeout_seconds=600] [interval_seconds=5]
Exit 0 once the host returns an SSH banner; exit 1 if the deadline elapses.
"""
import socket
import sys
import time


def ssh_answering(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=5) as sock:
            sock.settimeout(5)
            return sock.recv(64).startswith(b"SSH-")
    except OSError:
        return False


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "usage: wait_for_ssh.py <host> [port] [timeout_seconds] [interval_seconds]",
            file=sys.stderr,
        )
        return 2

    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 22
    timeout = float(sys.argv[3]) if len(sys.argv) > 3 else 600.0
    interval = float(sys.argv[4]) if len(sys.argv) > 4 else 5.0

    deadline = time.monotonic() + timeout
    attempt = 0
    while time.monotonic() < deadline:
        attempt += 1
        if ssh_answering(host, port):
            print(f"{host}:{port} is answering SSH (attempt {attempt}).")
            return 0
        time.sleep(interval)

    print(f"timed out after {timeout:.0f}s waiting for SSH on {host}:{port}.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
