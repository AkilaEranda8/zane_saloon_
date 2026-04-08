import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('157.180.113.249', username='root', password='qnuwjheuweugdsjsds')

# Check the update function catch block errors
cmd = 'sed -n "230,250p" /root/xanesalon/backend/controllers/appointmentController.js'
stdin, stdout, stderr = client.exec_command(cmd)
lines = stdout.read().decode()
for i, line in enumerate(lines.split('\n'), 230):
    print(f'{i}: {line}')

client.close()
