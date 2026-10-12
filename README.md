# linux-admin-toolkit

Scripts I keep reusing for Linux admin work. Nothing fancy, they just
save me from re-googling the same flags every time. Tested on Ubuntu 22.04.

## Scripts

### disk-alert.sh
Posts to a webhook when disk usage crosses a threshold. Meant for cron.

```bash
export ALERT_WEBHOOK="https://hooks.slack.com/services/xxx"
./scripts/disk-alert.sh 85 /var        # alert at 85% on /var
./scripts/disk-alert.sh               # defaults: 85% on /
./scripts/disk-alert.sh --help
```

### health-check.sh
One-line cpu/mem/disk/load summary. Exits 1 when anything is over its
warning threshold, so cron or a monitoring agent can catch it.

```bash
./scripts/health-check.sh
./scripts/health-check.sh --cpu-warn 70 --mem-warn 90 --disk-warn 90 --mount /data
```

### archive-logs.sh
Gzips `*.log` files older than N days. With an S3 bucket arg it uploads
the archives and deletes local originals only after a successful upload.

```bash
./scripts/archive-logs.sh /var/log/myapp 30
./scripts/archive-logs.sh /var/log/myapp 30 s3://my-backups/log-archive
```

### add-user.sh
Creates a user, installs their SSH public key, adds them to sudo. Run as root.

```bash
sudo ./scripts/add-user.sh deploy /tmp/deploy.pub
```

### patch-check.sh
Lists pending security updates (apt). `--apply` installs them; it will
tell you if a reboot is required but never reboots on its own.

```bash
./scripts/patch-check.sh
./scripts/patch-check.sh --apply
```

### backup-to-s3.sh
Tars the given dirs with a date stamp, uploads to S3, keeps the last N
archives locally. Put a lifecycle rule on the bucket for S3-side expiry.

```bash
./scripts/backup-to-s3.sh s3://my-backups/daily 7 /etc/nginx /opt/app/data
```

## Cron examples

```cron
# disk + health checks every 15 min
*/15 * * * * ALERT_WEBHOOK="https://hooks.slack.com/services/xxx" /opt/linux-admin-toolkit/scripts/disk-alert.sh 85 / >> /var/log/disk-alert.log 2>&1
*/15 * * * * /opt/linux-admin-toolkit/scripts/health-check.sh --disk-warn 90 >> /var/log/health.log 2>&1

# nightly log archival and backups
0 2 * * * /opt/linux-admin-toolkit/scripts/archive-logs.sh /var/log/myapp 30 s3://my-backups/log-archive
0 3 * * * /opt/linux-admin-toolkit/scripts/backup-to-s3.sh s3://my-backups/daily 7 /etc/nginx /opt/app/data

# weekly patch report (mondays)
0 8 * * 1 /opt/linux-admin-toolkit/scripts/patch-check.sh | mail -s "patch report $(hostname -s)" me@example.com
```

## Notes

- Scripts that touch the system (`add-user.sh`, `patch-check.sh --apply`) need root.
- Webhook URL and S3 buckets come from env/args, never hardcoded.

## License

MIT. See [LICENSE](LICENSE).
