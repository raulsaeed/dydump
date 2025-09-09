import socket
import threading
import argparse

class LogServer:
    def __init__(self, host='0.0.0.0', port=5021):
        self.host = host
        self.port = port
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        
    def start(self):
        try:
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(5) # Increased backlog slightly
            print(f"Server listening on {self.host}:{self.port}", flush=True)
            
            while True:
                try:
                    client_socket, address = self.server_socket.accept()
                    print(f"Connected to iOS device at {address}", flush=True)
                    client_handler = threading.Thread(
                        target=self.handle_client,
                        args=(client_socket, address) # Pass address for logging
                    )
                    client_handler.daemon = True # Allow main program to exit even if threads are running
                    client_handler.start()
                except KeyboardInterrupt:
                    print("\nShutting down server...", flush=True)
                    break
                except Exception as e:
                    print(f"Error accepting connection: {e}", flush=True)
                    # Depending on the error, you might want to continue or break
                    # For a simple server, breaking might be safer if accept fails unexpectedly
                    break 
        finally:
            print("Closing server socket.", flush=True)
            self.server_socket.close()
            
    def handle_client(self, client_socket, address):
        print(f"Handler started for {address}", flush=True)
        try:
            while True:
                try:
                    data = client_socket.recv(4096)
                    if not data:
                        # Client closed connection or sent empty data signaling EOF
                        print(f"Connection closed by {address} (received empty data).", flush=True)
                        break
                        
                    message = data.decode('utf-8')
                    # Critical change: ensure print flushes, especially since end='' is used.
                    print(message, end='', flush=True) 
                        
                except UnicodeDecodeError as e:
                    print(f"UnicodeDecodeError from {address}: {e}. Raw data (first 100 bytes): {data[:100]!r}", flush=True)
                    break 
                except socket.error as e:
                    print(f"Socket error with {address}: {e}", flush=True)
                    break
                except Exception as e:
                    print(f"Error handling client {address}: {e}", flush=True)
                    break
        finally:
            print(f"Closing connection for {address}.", flush=True)
            client_socket.close()

def main():
    parser = argparse.ArgumentParser(description='iOS Log Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host address')
    parser.add_argument('--port', type=int, default=5021, help='Port number')
    args = parser.parse_args()
    
    server = LogServer(args.host, args.port)
    server.start()

if __name__ == '__main__':
    main()
