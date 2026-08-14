#!/usr/bin/env python3
"""ct_receiver_daemon - listen 127.0.0.1:<port> (argv[1], default 9998), receive base64 -> decode -> sh exec -> return result"""
import socket, base64, sys, os, subprocess, threading, time
LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 9998
OUTPUT_DIR = "/tmp/ct_exec"
def handle(conn, addr):
    try:
        data = b''
        while True:
            chunk = conn.recv(65536)
            if not chunk: break
            data += chunk
        if not data: conn.close(); return
        decoded = base64.b64decode(data).decode('utf-8')
        fpath = os.path.join(OUTPUT_DIR, f"code_{int(time.time()*1000)}.sh")
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        with open(fpath, 'w') as f: f.write(decoded)
        os.chmod(fpath, 0o755)
        result = subprocess.run(['sh', fpath], capture_output=True, text=True, timeout=600)
        out = f"OK:{len(decoded)}:{result.returncode}\n"
        if result.stdout: out += result.stdout
        if result.stderr: out += result.stderr
        conn.sendall(out.encode()); conn.close()
        os.remove(fpath)
    except Exception as e:
        try: conn.sendall(f"ERR:{e}\n".encode()); conn.close()
        except: pass
        sys.stderr.write(f"ERR:{e}\n"); sys.stderr.flush()
def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(('127.0.0.1', LISTEN_PORT))
    srv.listen(10)
    sys.stdout.write(f"LISTEN:{LISTEN_PORT}\n"); sys.stdout.flush()
    while True:
        conn, addr = srv.accept()
        t = threading.Thread(target=handle, args=(conn, addr), daemon=True)
        t.start()
if __name__ == '__main__': main()