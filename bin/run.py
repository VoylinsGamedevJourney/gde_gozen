#!/usr/bin/env python

import os
import ssl
import sys

from http.server import HTTPServer, SimpleHTTPRequestHandler


class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Accept')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; connect-src *;")
        SimpleHTTPRequestHandler.end_headers(self)


def generate_self_signed_cert():
    if os.path.exists('server.pem'):
        print("Using existing SSL certificate.")
        return 'server.pem'

    print("Generating self-signed SSL certificate...")
    os.system('openssl req -new -x509 -keyout server.pem -out server.pem -days 365 -nodes -subj "/CN=localhost"')

    if os.path.exists('server.pem'):
        print("SSL certificate generated successfully.")
        return 'server.pem'
    else:
        print("Failed to generate SSL certificate.")
        return None


def run_server(port=8000, use_https=True):
    server_address = ('', port)
    httpd = HTTPServer(server_address, CORSRequestHandler)

    if use_https:
        # Set up HTTPS
        cert_file = generate_self_signed_cert()
        if cert_file:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certfile=cert_file)
            httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
            print(f"Starting HTTPS server on https://localhost:{port}")
        else:
            print(f"Falling back to HTTP server on http://localhost:{port}")
    else:
        print(f"Starting HTTP server on http://localhost:{port}")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    use_https = True  # Set to False if you want HTTP instead
    run_server(port, use_https)
