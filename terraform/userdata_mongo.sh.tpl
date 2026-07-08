#!/bin/bash
set -euxo pipefail

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

yum update -y || true
amazon-linux-extras install docker -y || yum install -y docker
amazon-linux-extras enable epel || true
yum install -y awscli cronie jq || true
systemctl enable --now docker
systemctl enable --now crond

mkdir -p /data/mongodb /opt/mongo-backup
chmod 700 /data/mongodb /opt/mongo-backup

cat >/etc/mongod.env <<ENVEOF
MONGO_INITDB_ROOT_USERNAME=${mongo_root_user}
MONGO_INITDB_ROOT_PASSWORD=${mongo_root_password}
ENVEOF
chmod 600 /etc/mongod.env

docker rm -f mongo || true

docker run -d \
  --restart unless-stopped \
  --name mongo \
  -p 27017:27017 \
  -v /data/mongodb:/data/db \
  --env-file /etc/mongod.env \
  mongo:5.0 \
  --auth --bind_ip_all

for i in $(seq 1 40); do
  if docker exec mongo mongosh -u ${mongo_root_user} -p '${mongo_root_password}' --authenticationDatabase admin --quiet --eval 'db.adminCommand({ ping: 1 }).ok' | grep -q 1; then
    break
  fi
  sleep 5
done

docker exec mongo mongosh -u ${mongo_root_user} -p '${mongo_root_password}' --authenticationDatabase admin --quiet --eval '
const appdb = db.getSiblingDB("wizexercise");
try {
  appdb.createUser({user:"${mongo_app_user}", pwd:"${mongo_app_password}", roles:[{role:"readWrite", db:"wizexercise"}]});
} catch (e) {
  if (!e.message.includes("already exists")) { throw e; }
}
appdb.todos.updateOne(
  {text:"seed from Terraform bootstrap"},
  {$setOnInsert:{text:"seed from Terraform bootstrap", completed:false, createdAt:new Date()}},
  {upsert:true}
);
'

cat >/usr/local/bin/backup-mongo-to-s3.sh <<'SCRIPTEOF'
#!/bin/bash
set -euo pipefail
TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
DEST="/opt/mongo-backup/mongodb-$${TS}.archive.gz"
docker exec mongo mongodump --username ${mongo_root_user} --password '${mongo_root_password}' --authenticationDatabase admin --archive --gzip > "$${DEST}"
aws s3 cp "$${DEST}" "s3://${backup_bucket}/mongo-backups/$(basename "$${DEST}")" --region ${aws_region}
find /opt/mongo-backup -type f -name 'mongodb-*.archive.gz' -mtime +3 -delete
SCRIPTEOF
chmod 700 /usr/local/bin/backup-mongo-to-s3.sh

cat >/etc/cron.d/mongo-backup <<CRONEOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
15 2 * * * root /usr/local/bin/backup-mongo-to-s3.sh >> /var/log/mongo-backup.log 2>&1
CRONEOF
chmod 644 /etc/cron.d/mongo-backup

/usr/local/bin/backup-mongo-to-s3.sh || true
