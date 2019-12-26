import socket as so
import threading as th

addr = ('127.0.0.1', 60000)

def receiver(conn, addr):
	with conn:
		while True:
			data = conn.recv(1024)
			if data:
				print(data)

with so.socket(so.AF_INET, so.SOCK_STREAM) as s:
	s.bind(addr)
	s.listen()

	while True:
		conn_args = s.accept()
		th.Thread(target=receiver, args=conn_args).start()
