import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('157.180.113.249', username='root', password='qnuwjheuweugdsjsds')

cmd = 'cd /root/xanesalon && tail -20 backend/controllers/appointmentController.js'
stdin, stdout, stderr = client.exec_command(cmd)
print('Last 20 lines:')
print(stdout.read().decode())

client.close()
