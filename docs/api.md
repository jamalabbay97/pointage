# REST API

All endpoints require HTTPS. Authenticated routes use `Authorization: Bearer <jwt>` and an `Idempotency-Key` header for writes.

- `POST /login`
- `POST /logout`
- `POST /attendance`
- `GET /history/:employeeId`
- `GET /reports`
- `GET /users/:id`
- `PATCH /users/:id`
- `POST /qr-codes`