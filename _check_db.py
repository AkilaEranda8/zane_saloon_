import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect('157.180.113.249', username='root', password='qnuwjheuweugdsjsds')

# Check database
cmd = "docker compose exec -T db mysql -u salon -pzane_salon_2024 -e 'SHOW TABLES LIKE \"appointment%\"; DESC appointment_services;'"
stdin, stdout, stderr = client.exec_command(cmd)
print('STDOUT:')
print(stdout.read().decode())
print('STDERR:')
print(stderr.read().decode())

client.close()
