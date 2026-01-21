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

# Access Bridge CLI
docker compose exec protonmail-bridge protonmail-bridge --cli
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
