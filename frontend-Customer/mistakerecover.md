Phase A — Backend: Customer Model & Auth
A1 — Create Customer model: { name, phone, otp, otpExpiry, createdAt }
A2 — POST /api/customers/register → name + phone, creates account
A3 — POST /api/customers/request-otp → generates OTP, stores hashed on customer (logs to console for now — no SMS provider yet)
A4 — POST /api/customers/verify-otp → validates OTP, returns JWT with { id, name, phone, role: "customer" }
A5 — Update auth.js middleware to accept customer JWTs too
A6 — Update POST /ride-requests to pull customerName from JWT (not from request body)
Phase B — Flutter: Customer Auth Flow
B1 — Add CustomerModel (id, name, phone)
B2 — Add customer endpoints to ApiService: register, requestOtp, verifyOtp
B3 — Update AuthProvider to use customer model + customer auth
B4 — Rewrite AuthScreen → phone number entry only (no email toggle)
B5 — PhoneVerificationScreen → real 6-digit OTP box wired to verifyOtp, no Firebase needed
B6 — New CustomerSignupScreen → name + phone (shown only on first registration)
B7 — Home screen shows customer name from auth
Phase C — Cleanup
C1 — Remove customerName input field from RideRequestScreen (comes from JWT now)
C2 — Remove all driver-auth code from Flutter (the email/password login, EmailVerificationScreen)