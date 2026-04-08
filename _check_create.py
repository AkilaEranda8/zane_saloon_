import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('157.180.113.249', username='root', password='qnuwjheuweugdsjsds')

# Check the create function area
cmd = 'sed -n "110,195p" /root/xanesalon/backend/controllers/appointmentController.js'
stdin, stdout, stderr = client.exec_command(cmd)
lines = stdout.read().decode()
for i, line in enumerate(lines.split('\n'), 110):
    print(f'{i}: {line}')

client.close()
