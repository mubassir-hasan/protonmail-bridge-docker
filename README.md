# ProtonMail Bridge Docker

Run ProtonMail Bridge in Docker to expose SMTP and IMAP for your email client.

## First Time Setup

1. Build the image:

   ```bash
   docker compose build
   ```

2. Initialize and login:

   ```bash
   docker compose run --rm protonmail-bridge bash /protonmail/entrypoint.sh init
   ```

   In the Bridge CLI:
   - `login` - Log in to your ProtonMail account
   - `info` - Show SMTP/IMAP credentials
   - `exit` - Exit the CLI

3. Start the container:

   ```bash
   docker compose up -d
   ```

## Regular Usage

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f protonmail-bridge
```

## Access Bridge CLI

To use the CLI while the container is running, you need to kill the running bridge process first:

```bash
# Exec into the container
docker compose exec protonmail-bridge bash

# Kill the running bridge process
pkill bridge

# Start CLI manually
protonmail-bridge --cli
```

After exiting the CLI, restart the container:

```bash
docker compose restart protonmail-bridge
```

## Ports

| Service | Host Port |
|---------|-----------|
| SMTP    | 1028      |
| IMAP    | 1154      |

## Email Client Configuration

- **SMTP Server:** 127.0.0.1:1028
- **IMAP Server:** 127.0.0.1:1154
- **Username:** Your ProtonMail email
- **Password:** Bridge-generated password (from `info` command)

## Data

Credentials are stored in the `protonmail-store` Docker volume.

## Testing

```bash
swaks --to recipient@example.com --from your-protonmail@protonmail.com --server 127.0.0.1:1028 --auth --auth-user your-protonmail@protonmail.com --auth-password YOUR_BRIDGE_PASSWORD
```

## Installation (on your Ubuntu server)

```bash
cd /home/cicd_user/protonmail-bridge-docker
sudo bash install-monitor-service.sh
Management Commands
```

## Check status

`systemctl status protonmail-monitor`

## View live logs

`journalctl -u protonmail-monitor -f`

## Stop/Start/Restart

```bash
systemctl stop protonmail-monitor
systemctl start protonmail-monitor
systemctl restart protonmail-monitor
```

## Disable autostart

`systemctl disable protonmail-monitor`