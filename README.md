# ask-the-llm

## Setting up Cal.com

This project includes Cal.com as a submodule. To set it up:

### Prerequisites
- Node.js (Version: >=18.x)
- PostgreSQL (Version: >=13.x)
- Yarn (recommended)
- Docker and Docker Compose (for quick start)

### Quick Start
```sh
cd cal.com
yarn dx
```
This will start a local Postgres instance with test users.

### Manual Setup
1. **Navigate to cal.com directory**
   ```sh
   cd cal.com
   ```

2. **Install dependencies**
   ```sh
   yarn
   ```

3. **Environment setup**
   ```sh
   cp .env.example .env
   # Generate secrets:
   openssl rand -base64 32  # Add to NEXTAUTH_SECRET in .env
   openssl rand -base64 32  # Add to CALENDSO_ENCRYPTION_KEY in .env
   ```

4. **Database setup**
   - Configure `DATABASE_URL` in `.env` file
   - Copy `DATABASE_URL` to `.env.appStore`
   - Run migrations:
     ```sh
     yarn workspace @calcom/prisma db-migrate
     ```

5. **Seed database (optional)**
   ```sh
   cd packages/prisma
   yarn db-seed
   ```

6. **Start development server**
   ```sh
   yarn dev
   ```

Access Cal.com at `http://localhost:3000`
