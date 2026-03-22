# LuxeSalon — Salon Management System

A full-stack salon management application built with **Node.js / Express / MySQL** on the backend and **React / Vite** on the frontend.

---

## Features

- **Dashboard** — Revenue stats, upcoming appointments, quick actions
- **Appointments & Calendar** — Book, confirm, complete, cancel with calendar view
- **Services** — Manage service catalog with categories, pricing, and durations
- **Staff** — Staff profiles, commission tracking, specializations
- **Customers** — Customer database with loyalty points and visit history
- **Payments** — Split payments (Cash/Card/Online/Loyalty), invoices with print
- **Commission** — Staff commission reports and payouts
- **Inventory** — Stock management with low-stock alerts
- **Attendance** — Daily staff attendance tracking
- **Reminders** — Task reminders with priority levels
- **Reports** — Revenue, service, and staff performance reports
- **Branches** — Multi-branch support (Admin+)
- **User Management** — Role-based access control (Admin+)
- **Online Booking** — Public booking page with 5-step wizard (no login required)

---

## Tech Stack

| Layer    | Technology                                    |
|----------|-----------------------------------------------|
| Backend  | Node.js, Express 4, Sequelize 6, MySQL        |
| Frontend | React 18, Vite 5, React Router 6, Recharts    |
| Auth     | JWT (httpOnly cookie), bcryptjs                |
| Styling  | Inline CSS-in-JS, Google Fonts                 |
| Docker   | Multi-stage builds, Nginx, MySQL 8              |

---

## Prerequisites

**Option A — Local development:**
- **Node.js** v18+ and **npm**
- **MySQL** 8.x (or MariaDB)

**Option B — Docker (recommended):**
- **Docker** and **Docker Compose**

---

## Quick Start with Docker

```bash
git clone <your-repo-url> salon_v1
cd salon_v1

# Build and start all services (MySQL + Backend + Frontend)
docker compose up -d --build

# Seed the database with demo data
docker compose run --rm seed

# Open in browser
# http://localhost
```

To stop:
```bash
docker compose down
```

To stop and wipe the database:
```bash
docker compose down -v
```

You can override defaults by creating a `.env` file at the project root:

```env
DB_PASS=your_mysql_root_password
DB_NAME=luxesalon
JWT_SECRET=your_strong_secret_here
```

---

## Local Setup (without Docker)

### 1. Clone & install dependencies

```bash
git clone <your-repo-url> salon_v1
cd salon_v1

# Install root dependencies (concurrently)
npm install

# Install backend + frontend dependencies
npm run install:all
```

### 2. Create the MySQL database

```sql
CREATE DATABASE luxesalon CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 3. Configure environment variables

Create `backend/.env`:

```env
DB_HOST=localhost
DB_USER=root
DB_PASS=
DB_NAME=luxesalon
JWT_SECRET=your_secret_key_change_this
PORT=5000
```

> **Note:** Change `JWT_SECRET` to a strong random string in production.

### 4. Seed the database

```bash
npm run seed
```

This runs three scripts in order:
1. **syncDB.js** — Creates/alters all tables
2. **seedUsers.js** — Creates 6 demo users with hashed passwords
3. **seedData.js** — Populates 3 branches, 6 services, 4 staff, 4 customers, 6 appointments, 4 payments, 5 inventory items, and 4 reminders

### 5. Start development servers

```bash
npm run dev
```

This starts both servers concurrently:
- **Backend API:** http://localhost:5000
- **Frontend:**    http://localhost:5173

---

## Demo Login Credentials

| Username     | Password      | Role        | Branch          |
|-------------|---------------|-------------|-----------------|
| `superadmin` | `admin123`    | Super Admin | All branches    |
| `admin`      | `admin123`    | Admin       | All branches    |
| `manager1`   | `manager123`  | Manager     | Main Branch     |
| `manager2`   | `manager123`  | Manager     | Downtown Branch |
| `staff1`     | `staff123`    | Staff       | Main Branch     |
| `staff2`     | `staff123`    | Staff       | Downtown Branch |

---

## Available Scripts

| Command              | Description                                 |
|---------------------|---------------------------------------------|
| `npm run dev`       | Start backend + frontend in dev mode         |
| `npm run seed`      | Run all database seeders                     |
| `npm run build`     | Build frontend for production                |
| `npm run install:all` | Install dependencies for both projects     |
| `npm start`         | Start backend only (production)              |

---

## Project Structure

```
salon_v1/
├── package.json              # Root scripts (dev, seed, build)
├── README.md
├── backend/
│   ├── .env                  # Environment variables
│   ├── package.json
│   ├── server.js             # Express app entry point
│   ├── config/
│   │   ├── database.js       # Sequelize connection
│   │   └── validateEnv.js    # Env validation on startup
│   ├── middleware/
│   │   ├── auth.js           # JWT verify, role guards
│   │   └── branchAccess.js   # Branch-level access control
│   ├── models/               # 12 Sequelize models + associations
│   ├── controllers/          # Business logic (13 controllers)
│   ├── routes/               # API route definitions (14 route files)
│   ├── scripts/
│   │   ├── seedAll.js        # Master seeder
│   │   ├── syncDB.js         # Table sync
│   │   ├── seedUsers.js      # Demo users
│   │   └── seedData.js       # Demo data
│   └── uploads/              # File uploads directory
└── frontend/
    ├── package.json
    ├── vite.config.js
    └── src/
        ├── App.jsx           # Routes & auth guards
        ├── main.jsx          # React entry point
        ├── api/axios.js      # Axios instance
        ├── context/AuthContext.jsx
        ├── components/
        │   ├── Layout.jsx
        │   └── shared/       # Reusable UI components + theme
        └── pages/            # 16 page components
```

---

## API Endpoints

### Public (no auth)
- `GET  /api/public/branches` — Active branches
- `GET  /api/public/services` — Active services
- `GET  /api/public/staff?branchId=` — Staff by branch
- `GET  /api/public/availability?staffId=&date=` — Booked slots
- `POST /api/public/bookings` — Create booking
- `GET  /api/health` — Health check

### Protected (requires JWT)
- `/api/auth` — Login, logout, current user
- `/api/branches` — CRUD branches
- `/api/services` — CRUD services
- `/api/staff` — CRUD staff
- `/api/appointments` — CRUD appointments
- `/api/customers` — CRUD customers
- `/api/payments` — Payments with splits & summary
- `/api/inventory` — Stock management
- `/api/attendance` — Attendance records
- `/api/reminders` — Task reminders
- `/api/reports` — Analytics & reports
- `/api/users` — User management (admin+)

---

## Online Booking

The public booking page is accessible at `/booking` — no login required.
Customers can book appointments through a 5-step wizard:

1. **Choose Branch** → 2. **Choose Service** → 3. **Pick Staff & Time** → 4. **Your Details** → 5. **Confirmation**

---

## License

Private — All rights reserved.
