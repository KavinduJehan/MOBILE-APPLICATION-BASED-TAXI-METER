# taxi-meter-backend

Node.js + Express backend for the Mobile Application-Based Taxi Meter System.

## Setup

1. Copy `.env.example` to `.env` and fill in your values:
   ```bash
   cp .env.example .env
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run in development mode:
   ```bash
   npm run dev
   ```

## API Endpoints

| Method | Endpoint                    | Auth     | Description                          |
|--------|-----------------------------|----------|--------------------------------------|
| POST   | /api/auth/register          | —        | Register a new driver                |
| POST   | /api/auth/login             | —        | Login and receive JWT                |
| GET    | /api/drivers/profile        | Bearer   | Get logged-in driver's profile       |
| POST   | /api/drivers/generate-qr   | Bearer   | Generate/refresh driver QR code      |
| GET    | /api/drivers/nearby?area=X  | —        | List verified drivers in an area     |
| GET    | /api/drivers/qr/:driverId   | —        | Lookup driver from scanned QR data   |
| PATCH  | /api/rates/my-rate          | Bearer   | Update driver's per-km rate          |
| GET    | /api/rates/area?area=X      | —        | Get average rate for an area         |
| POST   | /api/trips                  | Bearer   | Start a new trip                     |
| PATCH  | /api/trips/:id/end          | Bearer   | End trip and auto-generate receipt   |
| GET    | /api/trips/my               | Bearer   | Get driver's trip history            |

## Tech Stack
- **Runtime**: Node.js
- **Framework**: Express
- **Database**: MongoDB (Mongoose)
- **Auth**: JWT
- **QR**: qrcode
- **Hosting target**: Microsoft Azure
