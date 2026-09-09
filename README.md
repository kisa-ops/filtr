# filtr

A high-performance React + TypeScript data privacy and sanitization gateway built with Vite and Tailwind CSS.

---

## Production Deployment & Management

filtr includes automated production installation and zero-downtime upgrade scripts powered by Docker Compose and an optimized Alpine Nginx container.

### 1. First-Time Production Installation

To install and start the production stack:

```bash
./install.sh
```

By default, the application runs on port **`8080`** (`http://localhost:8080`).

#### Custom Options
```bash
# Specify a custom external port
./install.sh --port 3000

# Or build natively on a host with Node.js installed (without Docker)
./install.sh --native
```

### 2. Upgrading Production (Pushing / Applying Changes)

When you make changes or push updates to your code/git repository, run:

```bash
./upgrade.sh
```

The upgrade script will:
1. Automatically detect if Git is configured and pull the latest commits from your branch.
2. Rebuild the optimized Docker image.
3. Perform a zero-downtime recreation of the container.
4. Verify application health on the configured port.
5. Automatically clean up dangling Docker images.

#### Custom Upgrade Options
```bash
# Upgrade from local files without pulling from Git
./upgrade.sh --no-pull

# Pull and deploy a specific branch
./upgrade.sh --branch dev
```

### 3. Stack Management

```bash
# View live application & access logs
docker compose logs -f

# Check container status and health
docker compose ps

# Stop the container
docker compose stop

# Restart the container
docker compose restart

# Tear down the stack
docker compose down
```

---

## Configuration

Configuration is managed via `.env` (copied automatically from `.env.example` during install):

```env
# External host port
PORT=8080
```

---

## Development

To run locally in development mode:

```bash
npm install
npm run dev
```

To run linting or manual build:

```bash
npm run lint
npm run build
```
