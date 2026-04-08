import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('157.180.113.249', username='root', password='qnuwjheuweugdsjsds')

# Check the area around line 234
cmd = 'sed -n "230,240p" /root/xanesalon/backend/controllers/appointmentController.js'
stdin, stdout, stderr = client.exec_command(cmd)
print('Lines 230-240:')
lines = stdout.read().decode()
for i, line in enumerate(lines.split('\n'), 230):
    print(f'{i}: {line}')

client.close()
